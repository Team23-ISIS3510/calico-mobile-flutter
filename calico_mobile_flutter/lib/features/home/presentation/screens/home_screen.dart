import 'dart:async';

import 'package:calico_mobile_flutter/features/home/domain/entities/course_entity.dart';
import 'package:calico_mobile_flutter/features/home/domain/entities/session_entity.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../widgets/course_card.dart';
import '../widgets/session_card.dart';
import '../controllers/home_controller.dart';
import 'course_detail_screen.dart';
import 'session_detail_screen.dart';
import 'package:calico_mobile_flutter/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:calico_mobile_flutter/features/profile/presentation/screens/profile_screen.dart';
import '../../../../core/utils/context_aware_helper.dart';
import '../../../../core/services/motion_alert_service.dart';

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
  final _alertEmailController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _locationController = TextEditingController();
  int _selectedTab = 0;
  late final MotionAlertService _motionAlertService;
  bool _isAlertMonitoring = false;
  bool _isSendingAlert = false;

  // ── Stream: connectivity ────────────────────────────────────────────────
  // A Stream is an asynchronous sequence of events. Unlike a Future (one value),
  // a Stream emits zero or more values over time. StreamSubscription is the
  // handle returned by Stream.listen(); it lets us pause, resume, and — most
  // importantly — cancel the subscription. Canceling in dispose() is mandatory:
  // if we forget, the callback keeps firing after the widget is gone, causing
  // memory leaks and "setState called after dispose" crashes.
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    final client = ApiClient();
    _controller = HomeController(
      CourseRepositoryImpl(client),
      SessionRepositoryImpl(client),
    );
    _motionAlertService = MotionAlertService(apiClient: client);
    _controller.addListener(_onUpdate);
    _studentNameController.text =
        widget.studentId.isEmpty ? 'Estudiante' : widget.studentId;

    // ── Stream subscription: connectivity ─────────────────────────────────
    // We subscribe to the connectivity stream instead of polling because the
    // stream pushes changes to us the moment they happen (event-driven), while
    // polling would waste CPU and still miss rapid transitions between checks.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);

      // When coming back online: sync pending SQLite sessions and any pending
      // profile description edit, then refresh the pending-sessions list so
      // the ⏳ badges disappear for rows that were successfully confirmed.
      if (!offline && widget.studentId.isNotEmpty) {
        final client = ApiClient();
        SyncService(client).syncPendingSessions(widget.studentId).then((_) {
          if (!mounted) return;
          _controller.loadPendingSessions(widget.studentId);
          _controller.loadSessions(widget.studentId).then((_) {
            if (mounted) setState(() {});
          });
        });
        ProfileRepositoryImpl(client).syncPendingUpdate(widget.studentId);
      }
    });

    // ── Future.wait: parallel data loading ───────────────────────────────
    // Flutter runs on a single-threaded event loop (one Isolate). Async
    // functions do NOT create OS threads; they schedule continuations on the
    // event queue. Future.wait submits all three futures to the queue at once,
    // so their I/O wait times overlap — total latency equals the slowest call
    // rather than the sum of all calls.
    //
    // eagerError: false means every future runs to completion even if one
    // fails; we get partial data (e.g. courses without sessions) rather than
    // aborting everything on the first error, which is more resilient for a
    // home screen that can display partial state.
    _controller.markLoading();
    Future.wait(
      [
        _controller.loadCourses(widget.studentId),
        _controller.loadSessions(widget.studentId),
        _controller.loadPendingSessions(widget.studentId),
        _loadLocation(),
      ],
      eagerError: false,
    )
        .then((_) {
          _controller.markSuccess();
          if (mounted) setState(() {});
        })
        .catchError((e) {
          _controller.markFailure(e.toString());
          if (mounted) setState(() {});
        });
  }

  void _onUpdate() => setState(() {});

  // ── Location placeholder ──────────────────────────────────────────────────
  // Runs alongside the data fetches inside Future.wait. In a production build
  // this would call the geolocator or location package asynchronously.
  // Returning Future.value() immediately so it never delays the other futures.
  Future<void> _loadLocation() => Future.value();

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
    _alertEmailController.dispose();
    _studentNameController.dispose();
    _locationController.dispose();
    _motionAlertService.dispose();
    // Always cancel the StreamSubscription in dispose. The event loop holds a
    // reference to the callback closure; forgetting to cancel keeps the widget
    // alive in memory and causes setState-after-dispose errors.
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _toggleMotionMonitoring(bool enabled) async {
    if (enabled && _alertEmailController.text.trim().isEmpty) {
      _showSnackBar(
        'Ingresa el correo de alerta antes de activar el monitoreo.',
        isError: true,
      );
      return;
    }

    if (enabled) {
      _motionAlertService.start(onTriggered: _onMotionAlertTriggered);
      setState(() => _isAlertMonitoring = true);
      _showSnackBar('Monitoreo de movimiento activado.');
      return;
    }

    await _motionAlertService.stop();
    setState(() => _isAlertMonitoring = false);
    _showSnackBar('Monitoreo de movimiento detenido.');
  }

  Future<void> _onMotionAlertTriggered(String reason) async {
    if (_isSendingAlert) return;
    setState(() => _isSendingAlert = true);

    try {
      await _motionAlertService.sendEmergencyEmail(
        toEmail: _alertEmailController.text.trim(),
        toName: 'Tutor de guardia',
        studentName: _studentNameController.text.trim().isEmpty
            ? 'Estudiante'
            : _studentNameController.text.trim(),
        alertReason: reason,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      );
      if (mounted) {
        _showSnackBar('Alerta enviada por correo.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('No se pudo enviar la alerta: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingAlert = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lexend(fontSize: 14)),
        backgroundColor: isError ? const Color(0xFFB00020) : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                // ── Offline banner (Stream result) ──────────────────────
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
                      style: AppTextStyles.itemSubtitle
                          .copyWith(color: Colors.white),
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
                _EmergencyAlertCard(
                  alertEmailController: _alertEmailController,
                  studentNameController: _studentNameController,
                  locationController: _locationController,
                  isMonitoring: _isAlertMonitoring,
                  isSending: _isSendingAlert,
                  onToggleMonitoring: _toggleMotionMonitoring,
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
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
              onTap: () async {
                final booked = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(
                      course: c,
                      studentId: widget.studentId,
                      existingSessions: _controller.sessions,
                    ),
                  ),
                );
                if (booked == true) {
                  _controller.loadData(widget.studentId);
                }
              },
            ),
          ),

        // ── Pending sessions (queued offline in SQLite) ───────────────────
        // These rows have synced = false in the local DB. They are shown with
        // a ⏳ badge so the student knows they are not yet server-confirmed.
        // The list refreshes automatically when SyncService marks them synced.
        if (_controller.pendingSessions.isNotEmpty) ...[
          const SectionHeader('Pending Sync'),
          ..._controller.pendingSessions.map(
            (s) => SessionCard(
              session: s,
              showPendingBadge: true,
              onTap: () {},
            ),
          ),
        ],

        // ── Confirmed sessions ────────────────────────────────────────────
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

class _EmergencyAlertCard extends StatelessWidget {
  const _EmergencyAlertCard({
    required this.alertEmailController,
    required this.studentNameController,
    required this.locationController,
    required this.isMonitoring,
    required this.isSending,
    required this.onToggleMonitoring,
  });

  final TextEditingController alertEmailController;
  final TextEditingController studentNameController;
  final TextEditingController locationController;
  final bool isMonitoring;
  final bool isSending;
  final ValueChanged<bool> onToggleMonitoring;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBackground),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alerta por movimiento', style: AppTextStyles.itemTitle),
            const SizedBox(height: 6),
            Text(
              'Si detecta movimientos bruscos repetidos, se envia correo de emergencia.',
              style: AppTextStyles.itemSubtitle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de alerta',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: studentNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del estudiante',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Ubicacion (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMonitoring ? 'Monitoreo activo' : 'Monitoreo inactivo',
                    style: AppTextStyles.itemSubtitle,
                  ),
                ),
                if (isSending)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Switch(
                  value: isMonitoring,
                  onChanged: onToggleMonitoring,
                  activeThumbColor: AppColors.primary,
                ),
              ],
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
  final CourseEntity course;
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
  final SessionEntity session;
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
