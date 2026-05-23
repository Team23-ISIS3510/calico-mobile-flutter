import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../widgets/tutor_carousel_card.dart';
import 'courses_screen.dart';

/// Preliminary "Tutors" view — a base scaffold that pairs the existing
/// per-course tutor endpoint with a course-selector chip row so the student
/// can browse the bookable tutors for any course in the catalog.
///
/// Intentionally minimal: this is a foundation for the richer
/// "Tutor Search with Filters" view documented in `4.1.x`. It already
/// reuses every cache/connectivity helper the rest of the app uses, so a
/// future expansion only has to add filters / sorting on top of what's here.
class TutorsScreen extends StatefulWidget {
  final String studentId;

  const TutorsScreen({super.key, required this.studentId});

  @override
  State<TutorsScreen> createState() => _TutorsScreenState();
}

class _TutorsScreenState extends State<TutorsScreen> {
  final CourseRepositoryImpl _courseRepo = CourseRepositoryImpl(ApiClient());
  final AnalyticsRepositoryImpl _analyticsRepo =
      AnalyticsRepositoryImpl(ApiClient());

  List<CourseEntity> _courses = const [];
  CourseEntity? _selectedCourse;
  List<TutorEntity> _tutors = const [];

  bool _isLoadingCourses = true;
  bool _isLoadingTutors = false;
  bool _coursesLoadFailed = false;
  bool _tutorsLoadFailed = false;
  bool _isOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      setState(() => _isOffline = offline);
    }).catchError((_) {});
    _loadCourses();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);
    // On reconnect, retry whichever load previously failed so the screen
    // recovers without a user-driven retry tap.
    if (!offline) {
      if (_coursesLoadFailed) _loadCourses();
      if (_tutorsLoadFailed && _selectedCourse != null) _loadTutors();
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
      _coursesLoadFailed = false;
    });
    try {
      final courses = await _courseRepo.getCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoadingCourses = false;
        _coursesLoadFailed = false;
        // Default to the first course so the screen lands on real data.
        _selectedCourse ??= courses.isEmpty ? null : courses.first;
      });
      if (_selectedCourse != null) {
        _loadTutors();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
        _coursesLoadFailed = _courses.isEmpty;
      });
    }
  }

  Future<void> _loadTutors() async {
    final course = _selectedCourse;
    if (course == null) return;
    setState(() {
      _isLoadingTutors = true;
      _tutorsLoadFailed = false;
    });
    try {
      final tutors = await _analyticsRepo.getAvailableTutors(course.id);
      if (!mounted || _selectedCourse?.id != course.id) return;
      // Highest rating first — simple deterministic order for the base view.
      final sorted = [...tutors]
        ..sort((a, b) => b.rating.compareTo(a.rating));
      setState(() {
        _tutors = sorted;
        _isLoadingTutors = false;
        _tutorsLoadFailed = false;
      });
    } catch (_) {
      if (!mounted || _selectedCourse?.id != course.id) return;
      setState(() {
        _tutors = const [];
        _isLoadingTutors = false;
        _tutorsLoadFailed = true;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadCourses();
  }

  void _onCourseSelected(CourseEntity course) {
    if (_selectedCourse?.id == course.id) return;
    setState(() {
      _selectedCourse = course;
      _tutors = const [];
    });
    _loadTutors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _TutorsHeader(),
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Offline — showing cached data',
                      style: AppTextStyles.itemSubtitle
                          .copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _CourseChipRow(
                  courses: _courses,
                  selected: _selectedCourse,
                  isLoading: _isLoadingCourses,
                  onSelected: _onCourseSelected,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onTap: (i) => _onBottomNavTap(context, i),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCourses && _courses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (_coursesLoadFailed) {
      return _ErrorRetry(
        message: _isOffline
            ? 'Offline. Connect to load tutors.'
            : 'We could not load tutors right now. Please try again.',
        onRetry: _loadCourses,
      );
    }

    if (_selectedCourse == null) {
      return const _ScrollableEmpty(
        message: 'No courses available to browse tutors for.',
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            'Tutors for ${_selectedCourse!.name}',
          ),
        ),
        if (_isLoadingTutors)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          )
        else if (_tutorsLoadFailed)
          SliverToBoxAdapter(
            child: _InlineError(
              message: _isOffline
                  ? 'Offline. We couldn\'t reach the tutors service.'
                  : 'Could not load tutors for this course.',
              onRetry: _loadTutors,
            ),
          )
        else if (_tutors.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyStateView('No tutors available for this course yet.'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: _tutors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tutor = _tutors[index];
                return _TutorRow(
                  tutor: tutor,
                  onTap: () => _showComingSoon(tutor),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _showComingSoon(TutorEntity tutor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking ${tutor.name} from this view is coming soon. '
          'Open a course detail to book a session.',
          style: AppTextStyles.itemSubtitle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.brown,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 2) return; // Already on Tutors.
    if (index == 0) {
      // Home is the root — pop back to it instead of stacking another Home.
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CoursesScreen(studentId: widget.studentId),
        ),
      );
      return;
    }
    if (index == 3) {
      if (widget.studentId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Guest mode: please sign in to view your profile.',
              style:
                  AppTextStyles.itemSubtitle.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: widget.studentId),
        ),
      );
    }
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _TutorsHeader extends StatelessWidget {
  const _TutorsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: AppColors.background,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [AppLogo()],
      ),
    );
  }
}

class _CourseChipRow extends StatelessWidget {
  final List<CourseEntity> courses;
  final CourseEntity? selected;
  final bool isLoading;
  final ValueChanged<CourseEntity> onSelected;

  const _CourseChipRow({
    required this.courses,
    required this.selected,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && courses.isEmpty) {
      return const SizedBox(height: 56);
    }
    if (courses.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final course = courses[index];
          final isSelected = selected?.id == course.id;
          return ChoiceChip(
            label: Text(
              course.code.isNotEmpty ? course.code : course.name,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.black,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.inputBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
            onSelected: (_) => onSelected(course),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _TutorRow extends StatelessWidget {
  final TutorEntity tutor;
  final VoidCallback onTap;

  const _TutorRow({required this.tutor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Stretch the existing carousel card to fill the row width — keeps the
    // visual language consistent with the rest of the app without a new card.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          child: TutorCarouselCard(tutor: tutor, onTap: onTap),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.brown),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.itemSubtitle,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTextStyles.buttonLabel
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.itemSubtitle,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.buttonLabel
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  final String message;

  const _ScrollableEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        EmptyStateView(message),
      ],
    );
  }
}
