import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../widgets/tutor_carousel_card.dart';
import '../widgets/booking_bottom_sheet.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseEntity course;
  final String studentId;
  final List<SessionEntity> existingSessions;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.studentId,
    this.existingSessions = const [],
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<TutorEntity>? _tutors;
  bool _goToTutorLoaded = false;
  TutorEntity? _goToTutor;
  late final AnalyticsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AnalyticsRepositoryImpl(ApiClient());
    _loadTutors(_repo);
    if (widget.studentId.isNotEmpty) _loadGoToTutor(_repo);
  }

  Future<void> _loadTutors(AnalyticsRepository repo) async {
    try {
      final tutors = await repo.getAvailableTutors(widget.course.id);
      if (mounted) {
        setState(() => _tutors = tutors);
        repo.trackCarouselEvent(
          'results_shown',
          widget.course.id,
          resultCount: tutors.length,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _tutors = []);
    }
  }

  Future<void> _loadGoToTutor(AnalyticsRepository repo) async {
    try {
      final tutor = await repo.getReturningTutor(
        widget.studentId,
        widget.course.id,
      );
      if (mounted) {
        setState(() {
          _goToTutor = tutor;
          _goToTutorLoaded = true;
        });
      }
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
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 40,
                  color: AppColors.brown,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _InfoCard(
              children: [
                _InfoRow('Name', widget.course.name),
                _Divider(),
                _InfoRow('Code', widget.course.code),
                _Divider(),
                _InfoRow('Credits', widget.course.credits.toString()),
                _Divider(),
                _InfoRow('Faculty', widget.course.faculty),
              ],
            ),

            if (_goToTutorLoaded && _goToTutor != null) ...[
              const SizedBox(height: 24),
              _GoToTutorSection(
                tutor: _goToTutor!,
                studentId: widget.studentId,
                courseId: widget.course.id,
                existingSessions: widget.existingSessions,
              ),
            ],

            if (_tutors == null || _tutors!.isNotEmpty) ...[
              const SizedBox(height: 28),
              _TutorSection(
                tutors: _tutors,
                studentId: widget.studentId,
                courseId: widget.course.id,
                existingSessions: widget.existingSessions,
                onTutorTapped: (tutor) {
                  final countdown = tutor.nextSlotStart != null
                      ? tutor.nextSlotStart!.difference(DateTime.now()).inMinutes
                      : null;
                  _repo.trackCarouselEvent(
                    'tutor_clicked',
                    widget.course.id,
                    tutorId: tutor.id,
                    tutorRating: tutor.rating,
                    countdownMinutes: countdown,
                  );
                },
                onTutorBooked: (tutor) {
                  _repo.trackCarouselEvent(
                    'booking_completed',
                    widget.course.id,
                    tutorId: tutor.id,
                    tutorRating: tutor.rating,
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TutorSection extends StatelessWidget {
  final List<TutorEntity>? tutors;
  final String studentId;
  final String courseId;
  final List<SessionEntity> existingSessions;
  final void Function(TutorEntity tutor)? onTutorTapped;
  final void Function(TutorEntity tutor)? onTutorBooked;

  const _TutorSection({
    required this.tutors,
    required this.studentId,
    required this.courseId,
    required this.existingSessions,
    this.onTutorTapped,
    this.onTutorBooked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Top Rated & Available Soon',
              style: AppTextStyles.sectionTitle,
            ),
            if (tutors != null && tutors!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              itemBuilder: (context, i) {
                final tutor = tutors![i];
                final alreadyBooked = existingSessions
                    .any((s) => s.tutorId == tutor.id);
                return TutorCarouselCard(
                  tutor: tutor,
                  onTap: () async {
                    if (alreadyBooked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ya tienes una sesión pendiente con ${tutor.name}.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    onTutorTapped?.call(tutor);
                    final booked = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BookingBottomSheet(
                        tutor: tutor,
                        studentId: studentId,
                        courseId: courseId,
                        bookingSource: 'carousel',
                        onBooked: () => onTutorBooked?.call(tutor),
                      ),
                    );
                    if (booked == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GoToTutorSection extends StatelessWidget {
  final TutorEntity tutor;
  final String studentId;
  final String courseId;
  final List<SessionEntity> existingSessions;

  const _GoToTutorSection({
    required this.tutor,
    required this.studentId,
    required this.courseId,
    required this.existingSessions,
  });

  String _slotRange() {
    final start = tutor.nextSlotStart?.toLocal();
    if (start == null) return '';

    String fmt(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final dh = h % 12 == 0 ? 12 : h % 12;
      return '$dh:$m $period';
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
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      day = '${months[start.month - 1]} ${start.day}';
    }

    final end = tutor.nextSlotEnd?.toLocal();
    if (end != null) return '$day  ${fmt(start)} – ${fmt(end)}';
    return '$day  ${fmt(start)}';
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
    final slotRange = _slotRange();
    final countdown = _countdown();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Go-To Tutor', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'Your most-booked tutor for this course',
          style: AppTextStyles.itemSubtitle,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final alreadyBooked = existingSessions
                .any((s) => s.tutorId == tutor.id);
            if (alreadyBooked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Ya tienes una sesión pendiente con ${tutor.name}.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            final booked = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BookingBottomSheet(
                tutor: tutor,
                studentId: studentId,
                courseId: courseId,
                bookingSource: 'carousel',
              ),
            );
            if (booked == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE5D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
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
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
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
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (slotRange.isNotEmpty)
                          Text(
                            slotRange,
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                        if (countdown.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            countdown,
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: AppColors.brown,
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
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: AppTextStyles.itemSubtitle),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
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
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE9E1CF));
  }
}
