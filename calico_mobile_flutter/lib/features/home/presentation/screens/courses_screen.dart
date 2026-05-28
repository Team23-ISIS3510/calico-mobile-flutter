import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/course_filter_isolate.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/repositories/favorite_courses_repository.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/services/course_session_recency.dart';
import '../../domain/services/courses_view_snapshot_isolate.dart';
import '../widgets/course_card.dart';
import 'course_detail_screen.dart';
import 'tutors_screen.dart';

/// Full catalogue of courses with a Favorites strip on top. Reuses the
/// existing [CourseRepositoryImpl] LRU cache (10-min TTL, shared across the
/// app) so a warm Home → Courses navigation costs zero network calls.
///
/// Eventual-connectivity strategy:
/// - Cold start offline w/ warm cache → served instantly from LRU.
/// - Cold start offline w/o cache → friendly error + Retry button.
/// - Online → fresh fetch fills the LRU for the next screen.
/// - On reconnect (Connectivity stream) → silent background refresh if the
///   current data came from the cache (so the user is never stuck on stale).
class CoursesScreen extends StatefulWidget {
  final String studentId;

  const CoursesScreen({super.key, required this.studentId});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _searchController = TextEditingController();
  final CourseRepositoryImpl _repo = CourseRepositoryImpl(ApiClient());
  final SessionRepositoryImpl _sessionRepo = SessionRepositoryImpl(ApiClient());

  List<CourseEntity> _allCourses = const [];
  List<CourseEntity> _visibleCourses = const [];
  // Held in-memory so the favorites strip can keep rendering recency labels
  // without re-running the isolate when the toggle button is tapped.
  Map<String, int> _daysSinceLastSession = const {};
  // Materialized result of the most recent snapshot isolate run. Ordering is
  // authoritative — the UI iterates this list directly.
  List<CourseEntity> _sortedFavoriteCourses = const [];
  // Last sessions list pulled by [_loadData]. Cached so a favorites toggle can
  // re-run the snapshot isolate without re-fetching from the network.
  List<SessionEntity> _lastSessionsSnapshot = const [];
  // Monotonic counter used to discard stale isolate results (snapshot or
  // search) that resolve after a newer invocation has been queued.
  int _snapshotSeq = 0;
  int _searchSeq = 0;
  Timer? _searchDebounce;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 300);

  String _lastSearchQuery = '';
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isOffline = false;
  // True when the courses currently rendered came from the LRU cache and we
  // could not reach the server (best-effort fetch failed). Used to decide
  // whether to silently re-fetch on reconnect.
  bool _servedFromCacheFallback = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    FavoriteCoursesRepository.changes.addListener(_onFavoritesChanged);

    // Connectivity: track offline state + trigger silent refresh on reconnect.
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      setState(() => _isOffline = offline);
    }).catchError((_) {});

    // Favorites are lightweight — load and ignore the result; the listener
    // will rebuild once they arrive.
    FavoriteCoursesRepository.load();

    _loadData();
  }

  @override
  void dispose() {
    FavoriteCoursesRepository.changes.removeListener(_onFavoritesChanged);
    _connectivitySub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    // Rebuild synchronously so the heart icon on each row flips on the same
    // frame as the tap — readability of the toggle matters more than a tiny
    // setState. The favorites strip re-sort runs on the isolate; it'll
    // overwrite [_sortedFavoriteCourses] when ready.
    setState(() {});
    _runSnapshot(_lastSessionsSnapshot);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);

    // Silent refresh: if we were showing stale cache (because the last fetch
    // failed) and we just regained network, re-fetch in the background.
    if (!offline && _servedFromCacheFallback) {
      _loadData(silent: true);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final studentId = widget.studentId.trim();
      List<CourseEntity> courses = _allCourses;
      List<SessionEntity> sessions = _lastSessionsSnapshot;
      Object? coursesError;
      Object? sessionsError;

      try {
        courses = await _repo.getCourses();
      } catch (e) {
        coursesError = e;
      }

      try {
        sessions = studentId.isEmpty
            ? const []
            : await _sessionRepo.getStudentSessions(studentId);
      } catch (e) {
        sessionsError = e;
      }

      if (courses.isEmpty && coursesError != null && _allCourses.isEmpty) {
        throw coursesError;
      }

      if (!mounted) return;

      setState(() {
        if (courses.isNotEmpty) {
          _allCourses = courses;
        }
        _lastSessionsSnapshot = sessions;
        _isLoading = false;
        _loadFailed = false;
        _servedFromCacheFallback =
            coursesError != null || sessionsError != null;
      });

      _runSnapshot(sessions);
      _runFilter(_lastSearchQuery, immediate: true);
    } catch (_) {
      if (!mounted) return;
      // Cache may still hold data from a previous load — keep showing it.
      final hasCachedData = _allCourses.isNotEmpty;
      setState(() {
        _isLoading = false;
        _loadFailed = !hasCachedData;
        _servedFromCacheFallback = hasCachedData;
      });
    }
  }

  /// Offloads BQ6 + favorites ordering to a background isolate.
  ///
  /// Stale results from prior calls (e.g. the snapshot from a `_loadData` that
  /// resolved after a faster favorites-toggle re-run) are discarded by
  /// comparing the captured sequence number against [_snapshotSeq].
  void _runSnapshot(List<SessionEntity> sessions) {
    final seq = ++_snapshotSeq;
    final favoriteIds = FavoriteCoursesRepository.ids;
    prepareCoursesViewInIsolate(
      sessions: sessions,
      favoriteIds: favoriteIds,
      allCourses: _allCourses,
    ).then((snapshot) {
      if (!mounted || seq != _snapshotSeq) return;
      // Re-resolve IDs against _allCourses on the main thread — cheap O(n)
      // hash lookup, keeps CourseEntity off the isolate boundary.
      final coursesById = {for (final c in _allCourses) c.id: c};
      final ordered = <CourseEntity>[
        for (final id in snapshot.sortedFavoriteCourseIds)
          if (coursesById[id] != null) coursesById[id]!,
      ];
      setState(() {
        _daysSinceLastSession = snapshot.daysSinceLastSession;
        _sortedFavoriteCourses = ordered;
      });
    });
  }

  Future<void> _refresh() async {
    // Pull-to-refresh: force a network fetch by dropping the LRU entries.
    CourseRepositoryImpl.invalidate();
    final studentId = widget.studentId.trim();
    if (studentId.isNotEmpty) {
      SessionRepositoryImpl.invalidate(studentId);
    }
    await _loadData();
  }

  /// Keystroke handler. Debounces by [_searchDebounceDelay] before spawning
  /// the isolate so a fast typist fires one isolate run per word rather than
  /// per character (covers Micro-optimization 5 from Sprint 4).
  void _onSearchChanged(String query) {
    _lastSearchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDelay, () {
      _runFilter(query, immediate: true);
    });
  }

  /// Runs the course filter through [filterCoursesInIsolate].
  ///
  /// Both keystroke search (after debounce) and data-reload re-application go
  /// through this single path so the CPU work always happens off the main
  /// thread. Stale results are discarded with [_searchSeq] in case a later
  /// query resolves first.
  void _runFilter(String query, {bool immediate = false}) {
    final seq = ++_searchSeq;
    if (query.isEmpty) {
      // Empty query is the no-op fast path — assign synchronously, no isolate.
      setState(() => _visibleCourses = _allCourses);
      return;
    }
    if (_allCourses.isEmpty) return;
    filterCoursesInIsolate(_allCourses, query).then((filtered) {
      if (!mounted || seq != _searchSeq) return;
      setState(() => _visibleCourses = filtered);
    });
  }

  Future<void> _openCourse(CourseEntity course) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(
          course: course,
          studentId: widget.studentId,
        ),
      ),
    );
    if (!mounted) return;
    await _loadData(silent: true);
  }

  int? _daysSinceForCourse(String courseId) => _daysSinceLastSession[courseId];

  @override
  Widget build(BuildContext context) {
    final favoriteCourses = _sortedFavoriteCourses;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _CoursesHeader(),
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
                      style: AppTextStyles.itemSubtitle.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _CoursesSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: _buildBody(favoriteCourses),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onTap: (i) => _onBottomNavTap(context, i),
      ),
    );
  }

  Widget _buildBody(List<CourseEntity> favoriteCourses) {
    final favoriteIds = FavoriteCoursesRepository.ids;
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (_loadFailed && _allCourses.isEmpty) {
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
                  _isOffline
                      ? 'Offline. Connect to load the course catalog.'
                      : 'We could not load courses right now. Please try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.itemSubtitle,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _loadData(),
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
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Favorites ──────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: SectionHeader('Favorites')),
        if (favoriteCourses.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyStateView('Tap the heart on any course to save it here.'),
          )
        else
          SliverToBoxAdapter(
            child: SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favoriteCourses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final course = favoriteCourses[index];
                  final daysSince = _daysSinceForCourse(course.id);
                  return _FavoriteCourseChip(
                    course: course,
                    daysSinceLastSession: daysSince,
                    onTap: () => _openCourse(course),
                  );
                },
              ),
            ),
          ),

        // ── All courses ────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: SectionHeader('All Courses')),
        if (_visibleCourses.isEmpty)
          SliverToBoxAdapter(
            child: EmptyStateView(
              _lastSearchQuery.isEmpty
                  ? 'No courses available.'
                  : 'No courses match your search.',
            ),
          )
        else
          SliverList.builder(
            itemCount: _visibleCourses.length,
            itemBuilder: (context, index) {
              final c = _visibleCourses[index];
              final isFav = favoriteIds.contains(c.id);
              return _CourseRowWithFavorite(
                course: c,
                isFavorite: isFav,
                onTap: () => _openCourse(c),
                onFavoriteToggle: () => FavoriteCoursesRepository.toggle(c.id),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 1) return; // Already on Courses.
    if (index == 0) {
      // Back to Home — just pop instead of pushing a new Home screen.
      Navigator.pop(context);
      return;
    }
    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TutorsScreen(studentId: widget.studentId),
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

class _CoursesHeader extends StatelessWidget {
  const _CoursesHeader();

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

class _CoursesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CoursesSearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

class _FavoriteCourseChip extends StatelessWidget {
  final CourseEntity course;
  final int? daysSinceLastSession;
  final VoidCallback onTap;

  const _FavoriteCourseChip({
    required this.course,
    required this.daysSinceLastSession,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recencyLabel =
        CourseSessionRecency.labelFor(daysSinceLastSession);
    final showNudge = CourseSessionRecency.shouldNudge(daysSinceLastSession);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: showNudge
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: AppTextStyles.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    course.code,
                    style: AppTextStyles.itemSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recencyLabel,
                    style: AppTextStyles.itemSubtitle.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showNudge) ...[
                    const SizedBox(height: 2),
                    Text(
                      CourseSessionRecency.nudgeLabel(daysSinceLastSession),
                      style: AppTextStyles.itemSubtitle.copyWith(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseRowWithFavorite extends StatelessWidget {
  final CourseEntity course;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _CourseRowWithFavorite({
    required this.course,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Reuse the same CourseCard so the row matches Home aesthetically.
        CourseCard(course: course, onTap: onTap),
        Positioned(
          right: 44,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              onPressed: onFavoriteToggle,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? AppColors.primary : AppColors.brown,
                size: 22,
              ),
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              splashRadius: 20,
            ),
          ),
        ),
      ],
    );
  }
}
