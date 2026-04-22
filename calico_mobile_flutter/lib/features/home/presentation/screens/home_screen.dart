import 'package:flutter/material.dart';
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
import 'package:geolocator/geolocator.dart';

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
  bool _locationLoading = true;
  bool? _locationOnCampus;

  static const double _campusLat = 4.6015;
  static const double _campusLng = -74.0665;
  static const double _campusRadius = 500.0;

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
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _campusLat,
        _campusLng,
      );

      if (mounted) {
        setState(() {
          _locationLoading = false;
          _locationOnCampus = distance <= _campusRadius;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
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
                  backgroundColor: ContextAwareHelper.getBackgroundColor(),
                  accentColor: ContextAwareHelper.getAccentColor(),
                ),
                _LocationBadge(
                  isLoading: _locationLoading,
                  isOnCampus: _locationOnCampus,
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

    return ListView(
      children: [
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
                      isOnCampus: _locationOnCampus,
                    ),
                  ),
                );
                if (booked == true) _controller.loadData(widget.studentId);
              },
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
  final String icon;
  final Color backgroundColor;
  final Color accentColor;

  const _ContextAwareBanner({
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.itemTitle.copyWith(color: accentColor),
                  ),
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

class _LocationBadge extends StatelessWidget {
  final bool isLoading;
  final bool? isOnCampus;

  const _LocationBadge({required this.isLoading, required this.isOnCampus});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brown),
            ),
          ),
        ),
      );
    }

    if (isOnCampus == null) return const SizedBox.shrink();

    final onCampus = isOnCampus!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: onCampus
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            onCampus ? '📍 On Campus' : '🌐 Virtual Mode',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: onCampus
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );
  }
}

