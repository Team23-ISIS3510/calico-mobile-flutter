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
            // TODO!!!!!!: Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
          }
          setState(() => _selectedTab = i);
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
                child: Text('Retry',
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: AppColors.primary)),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(course: c)),
              ),
            ),
          ),

        // ── Sessions ─────────────────────────────────────────────────────
        const SectionHeader('Upcoming Sessions'),
        if (_controller.sessions.isEmpty)
          EmptyStateView(widget.studentId.isEmpty
              ? 'Sign in to see your sessions'
              : 'No upcoming sessions')
        else
          ..._controller.sessions.map(
            (s) => SessionCard(
              session: s,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(session: s)),
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
        children: [
          AppLogo(),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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

