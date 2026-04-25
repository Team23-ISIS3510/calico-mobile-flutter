import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../data/repositories/student_tutoring_repository_impl.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/repositories/student_tutoring_repository.dart';
import '../../data/repositories/student_tutoring_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
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
  bool _goToTutorFromCache = false;
  DateTime? _goToTutorLastUpdated;
  late final StudentTutoringRepository _tutoringRepo;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;
  bool _tutorsLoadFailed = false;
  /// True when the tutor list came from Hive fallback (see [StudentTutoringRepositoryImpl]).
  bool _tutorsFromCache = false;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final analyticsRepo = AnalyticsRepositoryImpl(client);
    _tutoringRepo = StudentTutoringRepositoryImpl(
      analyticsRepo,
      SessionRepositoryImpl(client),
      client,
    );
    _initConnectivity();
    _loadTutors();
    if (widget.studentId.isNotEmpty) _loadGoToTutor();
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _isOffline = initial.every((r) => r == ConnectivityResult.none));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final nowOffline = results.every((r) => r == ConnectivityResult.none);
      final wasOffline = _isOffline;
      setState(() => _isOffline = nowOffline);
      // Refresh as soon as we recover connectivity so stale/empty offline UI
      // is replaced without forcing the user to leave and re-enter the screen.
      if (wasOffline && !nowOffline) {
        _loadTutors();
        if (widget.studentId.isNotEmpty) _loadGoToTutor();
      }
    });
  }

  Future<void> _loadTutors() async {
    try {
      final result = await _tutoringRepo.getAvailableTutorsNext4Hours(
        widget.course.id,
      );
      if (mounted) {
        setState(() {
          _tutors = result.data;
          _tutorsFromCache = result.isFromCache;
          _tutorsLoadFailed = false;
          // Heuristic: if remote path succeeds (not cache fallback), we have
          // effective connectivity even if the OS network callback lags.
          if (!result.isFromCache) _isOffline = false;
        });
        await _tutoringRepo.trackCarouselEvent(
          'results_shown',
          widget.course.id,
          resultCount: result.data.length,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tutors = [];
          _tutorsLoadFailed = true;
          _tutorsFromCache = false;
          // Direct UX fallback: treat request failure as offline so the banner
          // appears even when Wi-Fi is connected but internet is unavailable.
          _isOffline = true;
        });
      }
    }
  }

  Future<void> _loadGoToTutor() async {
    try {
      final result = await _tutoringRepo.getGoToTutor(
        widget.studentId,
        widget.course.id,
      );
      if (mounted) {
        setState(() {
          _goToTutor = result.data;
          _goToTutorFromCache = result.isFromCache;
          _goToTutorLastUpdated = result.lastUpdated;
          _goToTutorLoaded = true;
          if (!result.isFromCache) _isOffline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _goToTutorFromCache = false;
          _goToTutorLastUpdated = null;
          _goToTutorLoaded = true;
          _isOffline = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
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
            if (_isOffline) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Application offline, showing cached data.',
                        style: AppTextStyles.itemSubtitle.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_goToTutorLoaded && _goToTutor != null) ...[
              const SizedBox(height: 24),
              _GoToTutorSection(
                tutor: _goToTutor!,
                studentId: widget.studentId,
                courseId: widget.course.id,
                existingSessions: widget.existingSessions,
                fromCache: _goToTutorFromCache || _isOffline,
                lastUpdated: _goToTutorLastUpdated,
              ),
            ],

            // Always show the carousel section so empty lists and errors still
            // render a heading + feedback (previously `[]` hid the whole block).
            const SizedBox(height: 28),
            _TutorSection(
              tutors: _tutors,
              loadFailed: _tutorsLoadFailed,
              fromCache: _tutorsFromCache || _isOffline,
              onRetry: _loadTutors,
              studentId: widget.studentId,
              courseId: widget.course.id,
              existingSessions: widget.existingSessions,
              onTutorTapped: (tutor) {
                final countdown = tutor.nextSlotStart
                    ?.difference(DateTime.now())
                    .inMinutes;
                _tutoringRepo.trackCarouselEvent(
                  'tutor_clicked',
                  widget.course.id,
                  tutorId: tutor.id,
                  tutorRating: tutor.rating,
                  countdownMinutes: countdown,
                );
              },
              onTutorBooked: (tutor) {
                _tutoringRepo.trackCarouselEvent(
                  'booking_completed',
                  widget.course.id,
                  tutorId: tutor.id,
                  tutorRating: tutor.rating,
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TutorSection extends StatelessWidget {
  final List<TutorEntity>? tutors;
  final bool loadFailed;
  final VoidCallback onRetry;
  final String studentId;
  final String courseId;
  final List<SessionEntity> existingSessions;
  final void Function(TutorEntity tutor)? onTutorTapped;
  final void Function(TutorEntity tutor)? onTutorBooked;
  // True when tutors were served from the Hive cache (device offline).
  final bool fromCache;

  const _TutorSection({
    required this.tutors,
    required this.loadFailed,
    required this.onRetry,
    required this.studentId,
    required this.courseId,
    required this.existingSessions,
    this.onTutorTapped,
    this.onTutorBooked,
    this.fromCache = false,
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
        // Shown when Hive returned expired/fallback data because we are offline.
        if (fromCache) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.cloud_off, size: 13, color: Colors.orange.shade600),
              const SizedBox(width: 4),
              Text(
                'Showing cached tutors',
                style: AppTextStyles.itemSubtitle.copyWith(
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        ],
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
        else if (tutors!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loadFailed
                      ? 'No pudimos cargar tutores para esta materia en este momento.'
                      : 'No hay tutores disponibles en las próximas 4 horas para esta materia.',
                  style: AppTextStyles.itemSubtitle,
                ),
                if (loadFailed) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    child: Text(
                      'Reintentar',
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: tutors!.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final tutor = tutors![i];
                final alreadyBooked = existingSessions.any(
                  (s) => s.tutorId == tutor.id,
                );
                return TutorCarouselCard(
                  tutor: tutor,
                  onTap: () async {
                    if (alreadyBooked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'You already have a pending session with ${tutor.name}.',
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
  final bool fromCache;
  final DateTime? lastUpdated;

  const _GoToTutorSection({
    required this.tutor,
    required this.studentId,
    required this.courseId,
    required this.existingSessions,
    this.fromCache = false,
    this.lastUpdated,
  });

  String _formatCacheTime(DateTime when) {
    final local = when.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

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
        if (fromCache) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.cloud_off, size: 13, color: Colors.orange.shade600),
              const SizedBox(width: 4),
              Text(
                lastUpdated != null
                    ? 'Showing cached information since: ${_formatCacheTime(lastUpdated!)}'
                    : 'Showing cached information',
                style: AppTextStyles.itemSubtitle.copyWith(
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final alreadyBooked = existingSessions.any(
              (s) => s.tutorId == tutor.id,
            );
            if (alreadyBooked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You already have a pending session with ${tutor.name}.',
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
