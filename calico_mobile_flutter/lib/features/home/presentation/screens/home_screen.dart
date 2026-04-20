import 'package:calico_mobile_flutter/features/home/data/models/course_model.dart';
import 'package:calico_mobile_flutter/features/home/data/models/session_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../widgets/course_card.dart';
import '../widgets/session_card.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../controllers/home_controller.dart';
import 'course_detail_screen.dart';
import 'session_detail_screen.dart';
import 'package:calico_mobile_flutter/features/profile/presentation/screens/profile_screen.dart';
import '../../../../core/utils/context_aware_helper.dart';

class HomeScreen extends StatefulWidget {
  /// Firebase UID of the logged-in student. Pass empty string for guest mode.
  final String studentId;

  const HomeScreen({super.key, required this.studentId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  final _searchController = TextEditingController();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _controller = HomeController(
      CourseRepositoryImpl(client),
      SessionRepositoryImpl(client),
    );
    _controller.addListener(_onUpdate);
    _controller.loadData(widget.studentId);
  }

  void _onUpdate() => setState(() {});

  String _getContextTitle() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _getContextMessage() {
    final hour = DateTime.now().hour;

    if (widget.studentId.isEmpty) {
      return 'Inicia sesión para ver recomendaciones personalizadas.';
    }

    if (hour < 12) {
      return _controller.sessions.isNotEmpty
          ? 'Empieza tu día revisando tus próximas sesiones.'
          : 'Es un buen momento para explorar cursos para hoy.';
    }

    if (hour < 18) {
      return _controller.sessions.isNotEmpty
          ? 'Aún tienes tiempo para prepararte para tu próxima sesión.'
          : 'Explora cursos y encuentra apoyo para tus clases.';
    }

    return _controller.sessions.isNotEmpty
        ? 'Revisa tus sesiones y prepárate para mañana.'
        : 'Un buen momento para repasar cursos antes de terminar el día.';
  }

  IconData _getContextIcon() {
    final hour = DateTime.now().hour;

    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 18) return Icons.light_mode_outlined;
    return Icons.nightlight_round;
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Fixed header + search (never scrolls) ──────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _HomeHeader(),
                _SearchBar(
                  controller: _searchController,
                  onChanged: _controller.search,
                ),
                _ContextAwareBanner(
                  title: ContextAwareHelper.getTitle(),
                  message: ContextAwareHelper.getMessage(
                    hasSessions: _controller.sessions.isNotEmpty,
                  ),
                  icon: ContextAwareHelper.getIcon(),
                ),
              ],
            ),
          ),

          // ── Scrollable content ──────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedTab,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: widget.studentId),
              ),
            );
          } else {
            setState(() => _selectedTab = i);
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_controller.status == HomeStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.brown),
              const SizedBox(height: 12),
              Text(
                _controller.error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: AppTextStyles.itemSubtitle,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _controller.loadData(widget.studentId),
                child: Text(
                  'Retry',
                  style: AppTextStyles.buttonLabel.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final recommended = _controller.recommendedCourses;

    return ListView(
      children: [
        // ── Recommended for you ──────────────────────────────────────────
        if (widget.studentId.isNotEmpty && recommended.isNotEmpty) ...[
          const SectionHeader('Recommended for you'),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final course = recommended[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(
                        course: course,
                        studentId: widget.studentId,
                      ),
                    ),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          course.name,
                          style: AppTextStyles.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(course.code, style: AppTextStyles.itemSubtitle),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Courses ──────────────────────────────────────────────────────
        const SectionHeader('Courses'),
        if (_controller.courses.isEmpty)
          const EmptyStateView('No courses found')
        else
          ..._controller.courses.map(
            (c) => CourseCard(
              course: c,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(
                    course: c,
                    studentId: widget.studentId,
                  ),
                ),
              ),
            ),
          ),

        // ── Sessions ─────────────────────────────────────────────────────
        const SectionHeader('Upcoming Sessions'),
        if (_controller.sessions.isEmpty)
          EmptyStateView(
            widget.studentId.isEmpty
                ? 'Sign in to see your sessions'
                : 'No upcoming sessions',
          )
        else
          ..._controller.sessions.map(
            (s) => SessionCard(
              session: s,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(session: s),
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // padding: 12px 16px — matches design spec
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left icon panel — beige, left-rounded only
            Container(
              width: 48,
              decoration: const BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.search, color: AppColors.brown, size: 24),
            ),
            // Right text field panel — beige, right-rounded only
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: AppTextStyles.searchHint,
                  decoration: InputDecoration(
                    hintText: 'Course name or code',
                    hintStyle: AppTextStyles.searchHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextAwareBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _ContextAwareBanner({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  const SizedBox(height: 4),
                  Text(message, style: AppTextStyles.itemSubtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      // padding: 20px 16px 12px — matches design spec
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(title, style: AppTextStyles.sectionTitle),
    );
  }
}

class _CourseItem extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _CourseItem({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // padding: 8px 16px, minHeight: 72px — matches design spec
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(minHeight: 72),
        color: AppColors.background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: icon + text
            Row(
              children: [
                // Book icon in beige square
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    size: 24,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                // Name + code
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(course.name, style: AppTextStyles.itemTitle),
                    Text(course.code, style: AppTextStyles.itemSubtitle),
                  ],
                ),
              ],
            ),
            // Right: chevron
            const Icon(Icons.chevron_right, size: 28, color: AppColors.black),
          ],
        ),
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const _SessionItem({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // padding: 12px 16px, minHeight: 90px — matches design spec
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 90),
        color: AppColors.background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: icon + text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar icon in orange square — design uses primary color
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 24,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                // Date + tutor + course
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(session.formattedDate, style: AppTextStyles.itemTitle),
                    Text(
                      session.displayTutor,
                      style: AppTextStyles.itemSubtitle,
                    ),
                    if (session.displayCourse.isNotEmpty)
                      Text(
                        session.displayCourse,
                        style: AppTextStyles.itemSubtitle,
                      ),
                  ],
                ),
              ],
            ),
            // Right: chevron
            const Icon(Icons.chevron_right, size: 28, color: AppColors.black),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(message, style: AppTextStyles.itemSubtitle),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.brown,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.lexend(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.lexend(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
