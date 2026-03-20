import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/available_tutor_model.dart';
import '../../data/models/course_model.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../widgets/tutor_carousel_card.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  final String studentId;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.studentId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  // null = still loading, [] = loaded but none found
  List<AvailableTutorModel>? _tutors;

  // Loaded after _tutors; only shown when non-null
  bool _goToTutorLoaded = false;
  AvailableTutorModel? _goToTutor;

  @override
  void initState() {
    super.initState();
    final repo = AnalyticsRepositoryImpl(ApiClient());
    _loadTutors(repo);
    if (widget.studentId.isNotEmpty) _loadGoToTutor(repo);
  }

  Future<void> _loadTutors(AnalyticsRepositoryImpl repo) async {
    try {
      final tutors = await repo.getAvailableTutors(widget.course.id);
      if (mounted) setState(() => _tutors = tutors);
    } catch (_) {
      if (mounted) setState(() => _tutors = []);
    }
  }

  Future<void> _loadGoToTutor(AnalyticsRepositoryImpl repo) async {
    try {
      final tutor = await repo.getReturningTutor(widget.studentId, widget.course.id);
      if (mounted) setState(() { _goToTutor = tutor; _goToTutorLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _goToTutorLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.course.name, style: AppTextStyles.itemTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon banner
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.menu_book_outlined,
                    size: 40, color: AppColors.brown),
              ),
            ),
            const SizedBox(height: 24),

            // Course info card
            _InfoCard(children: [
              _InfoRow('Name', widget.course.name),
              _Divider(),
              _InfoRow('Code', widget.course.code),
              _Divider(),
              _InfoRow('Credits', widget.course.credits.toString()),
              _Divider(),
              _InfoRow('Faculty', widget.course.faculty),
            ]),

            // Top Rated & Available Soon — only visible when loading or has data
            if (_tutors == null || _tutors!.isNotEmpty) ...[
              const SizedBox(height: 28),
              _TutorSection(tutors: _tutors),
            ],

            // Your Go-To Tutor — only shown once loaded and a result exists
            if (_goToTutorLoaded && _goToTutor != null) ...[
              const SizedBox(height: 28),
              _GoToTutorSection(tutor: _goToTutor!),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Tutor section ───────────────────────────────────────────────────────────

class _TutorSection extends StatelessWidget {
  final List<AvailableTutorModel>? tutors;

  const _TutorSection({required this.tutors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title + count badge
        Row(
          children: [
            Text('Top Rated & Available Soon',
                style: AppTextStyles.sectionTitle),
            if (tutors != null && tutors!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tutors!.length}',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Available in the next 4 hours for this course',
          style: AppTextStyles.itemSubtitle,
        ),
        const SizedBox(height: 14),

        // Loading spinner or horizontal carousel
        if (tutors == null)
          const SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: tutors!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => TutorCarouselCard(tutor: tutors![i]),
            ),
          ),
      ],
    );
  }
}

// ─── Go-To Tutor section ─────────────────────────────────────────────────────

class _GoToTutorSection extends StatelessWidget {
  final AvailableTutorModel tutor;

  const _GoToTutorSection({required this.tutor});

  @override
  Widget build(BuildContext context) {
    final times = tutor.bookingCount == 1 ? 'time' : 'times';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Go-To Tutor', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'You have booked this tutor ${tutor.bookingCount} $times for this course',
          style: AppTextStyles.itemSubtitle,
        ),
        const SizedBox(height: 14),
        TutorCarouselCard(tutor: tutor),
      ],
    );
  }
}

// ─── Reusable detail widgets ─────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 90,
              child: Text(label, style: AppTextStyles.itemSubtitle),
            ),
          ],
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: AppTextStyles.itemTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 1, color: Color(0xFFEDE5D0), indent: 16);
  }
}
