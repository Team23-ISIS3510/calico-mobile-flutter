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

            // Your Go-To Tutor — shown first, only when loaded with a result
            if (_goToTutorLoaded && _goToTutor != null) ...[
              const SizedBox(height: 24),
              _GoToTutorSection(tutor: _goToTutor!),
            ],

            // Top Rated & Available Soon — only visible when loading or has data
            if (_tutors == null || _tutors!.isNotEmpty) ...[
              const SizedBox(height: 28),
              _TutorSection(tutors: _tutors),
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

  String _slotRange() {
    final start = tutor.nextSlotStart;
    if (start == null) return '';
    String fmt(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = h < 12 ? 'AM' : 'PM';
      final dh = h % 12 == 0 ? 12 : h % 12;
      return '$dh:$m $p';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final slotDay = DateTime(start.year, start.month, start.day);
    String day;
    if (slotDay == today) {
      day = 'Today';
    } else if (slotDay == tomorrow) {
      day = 'Tomorrow';
    } else {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      day = '${months[start.month - 1]} ${start.day}';
    }
    final end = tutor.nextSlotEnd;
    return end != null ? '$day  ${fmt(start)} – ${fmt(end)}' : '$day  ${fmt(start)}';
  }

  String _countdown() {
    final start = tutor.nextSlotStart;
    if (start == null) return '';
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) return 'Ongoing';
    if (diff.inMinutes < 1) return 'Starting now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final times = tutor.bookingCount == 1 ? 'session' : 'sessions';
    final slotRange = _slotRange();
    final countdown = _countdown();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — icon + smaller title + "For You" badge
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 16, color: AppColors.brown),
            const SizedBox(width: 6),
            Text(
              'Your Go-To Tutor',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'For You',
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Based on your ${tutor.bookingCount} past $times with this tutor',
          style: AppTextStyles.itemSubtitle,
        ),
        const SizedBox(height: 12),

        // Full-width card with left orange accent bar
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Card body
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: const Border(
                      top: BorderSide(color: Color(0xFFEDE5D0)),
                      right: BorderSide(color: Color(0xFFEDE5D0)),
                      bottom: BorderSide(color: Color(0xFFEDE5D0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name + rating + booked badge
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
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
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 2),
                                    Text(
                                      tutor.rating.toStringAsFixed(1),
                                      style: GoogleFonts.lexend(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tutor.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.lexend(
                                          fontSize: 11,
                                          color: AppColors.brown,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Booked count chip
                          if (tutor.bookingCount != null &&
                              tutor.bookingCount! > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_rounded,
                                      size: 11, color: AppColors.brown),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${tutor.bookingCount}×',
                                    style: GoogleFonts.lexend(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brown,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Slot pill
                      if (slotRange.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 13, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  slotRange,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lexend(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              if (countdown.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  countdown,
                                  style: GoogleFonts.lexend(
                                    fontSize: 11,
                                    color: AppColors.brown,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
