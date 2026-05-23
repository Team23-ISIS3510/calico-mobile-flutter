import 'dart:async';

import 'package:calico_mobile_flutter/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:calico_mobile_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/campus_location_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/context_aware_helper.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/offline_cache_notice.dart';
import '../../../../core/widgets/section_header.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../data/repositories/student_tutoring_repository_impl.dart';
import '../controllers/home_controller.dart';
import '../widgets/course_card.dart';
import '../widgets/session_card.dart';
import 'course_detail_screen.dart';
import 'courses_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Firebase UID of the logged-in student. Pass empty string for guest mode.
  final String studentId;

  const HomeScreen({super.key, required this.studentId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeController _controller;
  final _searchController = TextEditingController();
  int _selectedTab = 0;

  late final StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;
  bool _isOffline = false;
  bool? _isOnCampus;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    final client = ApiClient();
    final tutoringRepo = StudentTutoringRepositoryImpl(
      AnalyticsRepositoryImpl(client),
      SessionRepositoryImpl(client),
      client,
    );
    _controller = HomeController(CourseRepositoryImpl(client), tutoringRepo);
    _controller.addListener(_onUpdate);
    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    if (widget.studentId.isNotEmpty) {
      Future.microtask(_trySyncIfOnline);
    }

    CampusLocationService.checkIsOnCampus()
        .then((result) {
          if (mounted) setState(() => _isOnCampus = result);
        })
        .catchError((_) {});

    _controller.markLoading();
    Future.wait([
          _controller.loadCourses(widget.studentId),
          _controller.loadSessions(widget.studentId),
          _controller.loadPendingSessions(widget.studentId),
        ], eagerError: false)
        .then((_) {
          if (!mounted) return;
          _controller.markSuccess();
        })
        .catchError((Object e) {
          if (!mounted) return;
          _controller.markFailure(e.toString());
        });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (mounted) setState(() => _isOffline = offline);

    if (!offline && widget.studentId.isNotEmpty) {
      _trySyncIfOnline();
      ProfileRepositoryImpl(ApiClient()).syncPendingUpdate(widget.studentId);
    }
  }

  Future<void> _retrySyncNow() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection — try again later.'),
        ),
      );
      return;
    }

    if (mounted) setState(() => _isSyncing = true);

    final result = await SyncService(
      ApiClient(),
    ).syncPendingSessions(widget.studentId);

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (result.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${result.errors.first}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }

    await _controller.loadPendingSessions(widget.studentId);
    if (result.synced > 0) {
      // Invalidate stale LRU cache so the reload fetches the confirmed sessions
      // from the server instead of returning the pre-sync cached list.
      SessionRepositoryImpl.invalidate(widget.studentId);
      await _controller.loadSessions(widget.studentId);

      if (mounted) {
        final label = result.synced == 1
            ? '1 pending booking was confirmed!'
            : '${result.synced} pending bookings were confirmed!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshAll() async {
    final client = ApiClient();
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((r) => r != ConnectivityResult.none);

    if (isOnline && widget.studentId.isNotEmpty) {
      // Best effort: refresh should not fail if sync endpoints are temporarily unavailable.
      bool syncedSomething = false;
      try {
        final result = await SyncService(client).syncPendingSessions(widget.studentId);
        syncedSomething = result.synced > 0;
      } catch (_) {}
      try {
        await ProfileRepositoryImpl(client).syncPendingUpdate(widget.studentId);
      } catch (_) {}
      // Drop the stale LRU cache whenever we just POSTed new sessions so that
      // loadData fetches the updated list from the server, not the old snapshot.
      if (syncedSomething) {
        SessionRepositoryImpl.invalidate(widget.studentId);
      }
    }

    // Always invalidate the course cache on an explicit pull-to-refresh so the
    // user sees the latest catalogue from the server, not a stale 10-min snapshot.
    CourseRepositoryImpl.invalidate();
    await _controller.loadData(widget.studentId);
  }

  // Called by Flutter when the app comes back to the foreground.
  // This is more reliable than the connectivity stream for catching
  // reconnections that happen while the app is backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.studentId.isNotEmpty) {
      _trySyncIfOnline();
    }
  }

  Future<void> _trySyncIfOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline =
          results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (!isOnline || !mounted) return;

      if (mounted) setState(() => _isSyncing = true);

      final result = await SyncService(
        ApiClient(),
      ).syncPendingSessions(widget.studentId);

      if (!mounted) return;
      setState(() => _isSyncing = false);

      await _controller.loadPendingSessions(widget.studentId);
      if (result.synced > 0) {
        // Invalidate the stale LRU cache so the next getStudentSessions call
        // fetches fresh data from the server (which now includes the synced sessions).
        SessionRepositoryImpl.invalidate(widget.studentId);
        await _controller.loadSessions(widget.studentId);
      }
      if (mounted) setState(() {});

      if (result.synced > 0 && mounted) {
        final label = result.synced == 1
            ? '1 pending booking was confirmed!'
            : '${result.synced} pending bookings were confirmed!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (result.hasErrors && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${result.errors.first}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    _searchController.dispose();
    _connectivitySubscription.cancel();
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
                _HomeHeader(isOnCampus: _isOnCampus),
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Sin conexión — mostrando datos en caché',
                      style: AppTextStyles.itemSubtitle.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              color: AppColors.primary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedTab,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoursesScreen(studentId: widget.studentId),
              ),
            );
            return;
          }
          if (i == 2) {
            if (widget.studentId.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Guest mode: please sign in to view your profile.',
                    style: AppTextStyles.itemSubtitle.copyWith(
                      color: Colors.white,
                    ),
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
            return;
          }
          setState(() => _selectedTab = i);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ],
      );
    }

    if (_controller.status == HomeStatus.failure) {
      final failureMessage = _isOffline
          ? 'Sin conexión. No pudimos actualizar Inicio, pero puedes reintentar cuando vuelvas a estar en línea.'
          : (_controller.error?.trim().isNotEmpty ?? false)
          ? _controller.error!
          : 'No pudimos cargar Inicio en este momento. Intenta de nuevo.';
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
                  failureMessage,
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
        ],
      );
    }

    final recommended = _controller.recommendedCourses;
    final courses = _controller.courses;
    final pending = _controller.pendingSessions;
    final sessions = _controller.sessions;

    // Micro-optimization 1: lazy lists via CustomScrollView + SliverList.builder.
    // Items are built on demand as they enter the viewport instead of eagerly
    // materializing every CourseCard / SessionCard on the first frame.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Recommended for you ──────────────────────────────────────────
        if (widget.studentId.isNotEmpty && recommended.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader('Recommended for you'),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recommended.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final course = recommended[index];
                  return GestureDetector(
                    onTap: () async {
                      final booked = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(
                            course: course,
                            studentId: widget.studentId,
                            existingSessions: [
                              ..._controller.sessions,
                              ..._controller.pendingSessions,
                            ],
                            isOnCampus: _isOnCampus,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      await _controller.loadPendingSessions(widget.studentId);
                      if (booked == true) {
                        _controller.loadData(widget.studentId);
                      }
                      if (mounted) setState(() {});
                    },
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
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // ── Courses (preview, up to 4) ───────────────────────────────────
        const SliverToBoxAdapter(
          child: SectionHeader('4 of your most recent courses'),
        ),
        if (courses.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyStateView('No courses found'),
          )
        else
          SliverList.builder(
            itemCount: courses.length > 4 ? 4 : courses.length,
            itemBuilder: (context, index) {
              final c = courses[index];
              return CourseCard(
                course: c,
                onTap: () async {
                  final booked = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(
                        course: c,
                        studentId: widget.studentId,
                        existingSessions: [
                          ..._controller.sessions,
                          ..._controller.pendingSessions,
                        ],
                        isOnCampus: _isOnCampus,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  await _controller.loadPendingSessions(widget.studentId);
                  if (booked == true) _controller.loadData(widget.studentId);
                  if (mounted) setState(() {});
                },
              );
            },
          ),
        if (courses.length > 4)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CoursesScreen(studentId: widget.studentId),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('See all courses'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

        // ── Pending sessions (queued offline in SQLite) ───────────────────
        if (pending.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pending Sync', style: AppTextStyles.sectionTitle),
                  _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _isOffline ? null : _retrySyncNow,
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Retry now'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: pending.length,
            itemBuilder: (context, index) => SessionCard(
              session: pending[index],
              showPendingBadge: true,
              onTap: () {},
            ),
          ),
        ],

        // ── Confirmed sessions ────────────────────────────────────────────
        const SliverToBoxAdapter(child: SectionHeader('Upcoming Sessions')),
        if (_isOffline || _controller.sessionsFromCache)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 13,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Loading data from cache',
                    style: AppTextStyles.itemSubtitle.copyWith(
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_controller.sessionsFromCache)
          SliverToBoxAdapter(
            child: OfflineCacheNotice(
              lastUpdated: _controller.sessionsLastUpdated,
            ),
          ),
        if (sessions.isEmpty)
          SliverToBoxAdapter(
            child: EmptyStateView(
              widget.studentId.isEmpty
                  ? 'Sign in to see your sessions'
                  : 'No upcoming sessions',
            ),
          )
        else
          SliverList.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];
              return SessionCard(
                session: s,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(session: s),
                  ),
                ),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final bool? isOnCampus;
  const _HomeHeader({this.isOnCampus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AppLogo(),
          if (isOnCampus != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOnCampus!
                    ? Colors.green.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnCampus! ? Icons.school : Icons.laptop,
                    size: 14,
                    color: isOnCampus!
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnCampus! ? 'In campus' : 'Virtual',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOnCampus!
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
