import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/course_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/course_repository_impl.dart';
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
      bottomNavigationBar: _BottomNav(
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
        _SectionHeader('Courses'),
        if (_controller.courses.isEmpty)
          _EmptyState('No courses found')
        else
          ..._controller.courses.map(
            (c) => _CourseItem(
              course: c,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(course: c)),
              ),
            ),
          ),

        // ── Sessions ─────────────────────────────────────────────────────
        _SectionHeader('Upcoming Sessions'),
        if (_controller.sessions.isEmpty)
          _EmptyState(widget.studentId.isEmpty
              ? 'Sign in to see your sessions'
              : 'No upcoming sessions')
        else
          ..._controller.sessions.map(
            (s) => _SessionItem(
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
      // padding: 16px 16px 8px — matches design spec
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/logo_calico.png',
            width: 178,
            height: 79,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              'Calico',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 28,
                color: AppColors.brown,
              ),
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
                  child: const Icon(Icons.menu_book_outlined,
                      size: 24, color: AppColors.black),
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
                  child: const Icon(Icons.calendar_today,
                      size: 24, color: AppColors.black),
                ),
                const SizedBox(width: 16),
                // Date + tutor + course
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(session.formattedDate,
                        style: AppTextStyles.itemTitle),
                    Text(session.displayTutor,
                        style: AppTextStyles.itemSubtitle),
                    if (session.displayCourse.isNotEmpty)
                      Text(session.displayCourse,
                          style: AppTextStyles.itemSubtitle),
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
          fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.lexend(
          fontSize: 12, fontWeight: FontWeight.w400),
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
