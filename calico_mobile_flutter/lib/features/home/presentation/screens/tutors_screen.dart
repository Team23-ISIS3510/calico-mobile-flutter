import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../search/data/repositories/tutor_search_repository_impl.dart';
import '../../data/models/available_tutor_model.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../widgets/booking_bottom_sheet.dart';
import 'courses_screen.dart';

/// Top-level function required by [compute] — must not be a closure.
List<Map<String, dynamic>> _filterByName(Map<String, dynamic> params) {
  final tutors = params['tutors'] as List<Map<String, dynamic>>;
  final query = (params['query'] as String).toLowerCase();
  if (query.isEmpty) return tutors;
  return tutors.where((t) {
    final name = (t['name'] as String? ?? '').toLowerCase();
    return name.contains(query);
  }).toList();
}

/// Tutor Search with Filters (FF015).
///
/// Replaces the previous minimal Tutors tab with a full search experience:
/// text search (debounced 400 ms), filter chips (Course, Rating, Location,
/// Price), Auto-Assign shortcut, and direct booking via [BookingBottomSheet].
class TutorsScreen extends StatefulWidget {
  final String studentId;

  const TutorsScreen({super.key, required this.studentId});

  @override
  State<TutorsScreen> createState() => _TutorsScreenState();
}

class _TutorsScreenState extends State<TutorsScreen> {
  late final TutorSearchRepositoryImpl _repository;
  final CourseRepositoryImpl _courseRepo = CourseRepositoryImpl(ApiClient());

  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _isOffline = false;

  // Search state
  final _nameController = TextEditingController();
  Timer? _debounceTimer;
  Map<String, dynamic>? _lastSearchParams;

  // Results
  List<AvailableTutorModel> _allResults = [];
  List<AvailableTutorModel> _results = [];
  bool _isLoading = false;

  // Filter values
  List<CourseEntity> _courses = [];
  String _selectedCourseId = '';
  double _minRating = 0.0;
  String _locationType = 'all';
  double _maxPrice = double.infinity;

  @override
  void initState() {
    super.initState();
    _repository = TutorSearchRepositoryImpl(ApiClient());

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(() => _isOffline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none));
    });

    _loadCourses();
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    _debounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);
    if (!offline && _lastSearchParams != null) {
      _search(_lastSearchParams!);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _courseRepo.getCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
      // Auto-select first course and trigger initial search.
      if (courses.isNotEmpty && _selectedCourseId.isEmpty) {
        _selectedCourseId = courses.first.id;
        _search({
          'courseId': _selectedCourseId,
          'minRating': _minRating,
          'locationType': _locationType,
        });
      }
    } catch (_) {}
  }

  // ── Name search with debounce + compute() ───────────────────────────

  void _onNameSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // Serialize models to plain maps so compute() can cross the isolate
      // boundary (AvailableTutorModel is not SendPort-safe).
      final maps = _allResults
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'rating': t.rating,
                'hourlyRate': t.hourlyRate,
                'profileImage': t.profileImage,
                'location': t.location,
                'nextSlotStart': t.nextSlotStart?.toIso8601String(),
                'nextSlotEnd': t.nextSlotEnd?.toIso8601String(),
                'parentAvailabilityId': t.parentAvailabilityId,
                'nextSlotIndex': t.nextSlotIndex,
                'availableSlotsCount': t.availableSlotsCount,
                'bookingCount': t.bookingCount,
              })
          .toList();

      final filtered =
          await compute(_filterByName, {'tutors': maps, 'query': query});

      final ids = filtered.map((m) => m['id'] as String).toSet();
      if (!mounted) return;
      setState(() {
        _results = _allResults.where((t) => ids.contains(t.id)).toList();
      });
    });
  }

  // ── API search through repository ────────────────────────────────────

  Future<void> _search(Map<String, dynamic> params) async {
    _lastSearchParams = params;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final tutors = await _repository.searchTutors(
        courseId: params['courseId'] as String? ?? '',
        minRating: (params['minRating'] as num?)?.toDouble() ?? 0.0,
        locationType: params['locationType'] as String? ?? 'all',
      );
      if (!mounted) return;

      // Apply local price filter
      final priceFiltered = _maxPrice == double.infinity
          ? tutors
          : tutors
              .where(
                  (t) => (t.hourlyRate ?? 0) <= _maxPrice)
              .toList();

      setState(() {
        _allResults = priceFiltered;
        _results = priceFiltered;
        _isLoading = false;
      });

      // Re-apply name filter if active
      if (_nameController.text.isNotEmpty) {
        _onNameSearchChanged(_nameController.text);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _triggerSearch() {
    _search({
      'courseId': _selectedCourseId,
      'minRating': _minRating,
      'locationType': _locationType,
    });
  }

  // ── Auto-assign ──────────────────────────────────────────────────────

  void _autoAssign() {
    if (_results.isEmpty) return;
    _openBooking(_results.first);
  }

  void _openBooking(AvailableTutorModel tutor) {
    final entity = tutor.toEntity();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingBottomSheet(
        tutor: entity,
        studentId: widget.studentId,
        courseId: _selectedCourseId,
        bookingSource: 'search',
        onBooked: _triggerSearch,
      ),
    );
  }

  // ── Filter dialogs ───────────────────────────────────────────────────

  void _showCourseFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Select Course', style: AppTextStyles.sectionTitle),
        children: _courses.map((c) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedCourseId = c.id);
              _triggerSearch();
            },
            child: Text(
              c.code.isNotEmpty ? '${c.code} — ${c.name}' : c.name,
              style: AppTextStyles.itemTitle.copyWith(
                color:
                    c.id == _selectedCourseId ? AppColors.primary : AppColors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showRatingFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Minimum Rating', style: AppTextStyles.sectionTitle),
        children: [0.0, 3.0, 4.0, 4.5].map((r) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _minRating = r);
              _triggerSearch();
            },
            child: Text(
              r == 0 ? 'Any rating' : '${r.toString()}+ stars',
              style: AppTextStyles.itemTitle.copyWith(
                color: r == _minRating ? AppColors.primary : AppColors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLocationFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Location', style: AppTextStyles.sectionTitle),
        children: [
          {'key': 'all', 'label': 'All locations'},
          {'key': 'virtual', 'label': 'Virtual only'},
          {'key': 'campus', 'label': 'In-person only'},
        ].map((opt) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _locationType = opt['key']!);
              _triggerSearch();
            },
            child: Text(
              opt['label']!,
              style: AppTextStyles.itemTitle.copyWith(
                color: opt['key'] == _locationType
                    ? AppColors.primary
                    : AppColors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showPriceFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Max Price', style: AppTextStyles.sectionTitle),
        children: [
          {'value': double.infinity, 'label': 'Any price'},
          {'value': 20.0, 'label': 'Up to \$20/h'},
          {'value': 30.0, 'label': 'Up to \$30/h'},
          {'value': 50.0, 'label': 'Up to \$50/h'},
        ].map((opt) {
          final val = opt['value'] as double;
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _maxPrice = val);
              _triggerSearch();
            },
            child: Text(
              opt['label'] as String,
              style: AppTextStyles.itemTitle.copyWith(
                color: val == _maxPrice ? AppColors.primary : AppColors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: AppColors.background,
              child: const Row(
                children: [AppLogo()],
              ),
            ),

            // Offline banner
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.orange.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are offline — cached results shown',
                        style: AppTextStyles.itemSubtitle
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Tutors', style: AppTextStyles.sectionTitle),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _nameController,
                onChanged: _onNameSearchChanged,
                enabled: !_isOffline,
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: GoogleFonts.lexend(
                    fontSize: 14,
                    color: AppColors.brown,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.brown),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.lexend(fontSize: 14, color: AppColors.black),
              ),
            ),

            // Filter chips row
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChipWidget(
                    label: _maxPrice == double.infinity
                        ? 'Price'
                        : '\$${_maxPrice.toInt()}',
                    isActive: _maxPrice != double.infinity,
                    onTap: _showPriceFilter,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipWidget(
                    label: _locationType == 'all'
                        ? 'Location'
                        : _locationType == 'virtual'
                            ? 'Virtual'
                            : 'In-person',
                    isActive: _locationType != 'all',
                    onTap: _showLocationFilter,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipWidget(
                    label: _selectedCourseId.isEmpty
                        ? 'Course'
                        : _courses
                                .where((c) => c.id == _selectedCourseId)
                                .map((c) =>
                                    c.code.isNotEmpty ? c.code : c.name)
                                .firstOrNull ??
                            'Course',
                    isActive: _selectedCourseId.isNotEmpty,
                    onTap: _showCourseFilter,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipWidget(
                    label: _minRating == 0
                        ? 'Rating'
                        : '${_minRating.toString()}+',
                    isActive: _minRating > 0,
                    onTap: _showRatingFilter,
                  ),
                ],
              ),
            ),

            // Auto-Assign
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Material(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome,
                      color: AppColors.primary),
                  title: Text('Auto-Assign',
                      style: GoogleFonts.lexend(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Book the best available tutor instantly',
                    style: GoogleFonts.lexend(
                        fontSize: 12, color: AppColors.brown),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.brown),
                  onTap: _autoAssign,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Tutor list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No tutors found. Try clearing filters.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.itemSubtitle,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _triggerSearch(),
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final tutor = _results[i];
                              return _TutorListTile(
                                tutor: tutor,
                                onTap: () => _openBooking(tutor),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onTap: (i) => _onBottomNavTap(context, i),
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 2) return;
    if (index == 0) {
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
              style: AppTextStyles.itemSubtitle.copyWith(color: Colors.white),
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

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : AppColors.black,
          ),
        ),
        backgroundColor: isActive ? AppColors.primary : AppColors.inputBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TutorListTile extends StatelessWidget {
  final AvailableTutorModel tutor;
  final VoidCallback onTap;

  const _TutorListTile({required this.tutor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                backgroundImage: tutor.profileImage != null &&
                        tutor.profileImage!.isNotEmpty
                    ? NetworkImage(tutor.profileImage!)
                    : null,
                child: tutor.profileImage == null || tutor.profileImage!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),

              // Name + location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tutor.location,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: AppColors.brown,
                      ),
                    ),
                    if (tutor.hourlyRate != null)
                      Text(
                        '\$${tutor.hourlyRate!.toStringAsFixed(0)}/h',
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: AppColors.brown,
                        ),
                      ),
                  ],
                ),
              ),

              // Rating badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      tutor.rating.toStringAsFixed(1),
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
