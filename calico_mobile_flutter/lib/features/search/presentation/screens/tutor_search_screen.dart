import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../home/data/models/available_tutor_model.dart';
import '../../../home/presentation/widgets/booking_bottom_sheet.dart';
import '../../data/repositories/tutor_search_repository_impl.dart';
import '../../../../core/network/api_client.dart';
import '../controllers/tutor_search_controller.dart';

class TutorSearchScreen extends StatefulWidget {
  final String studentId;

  const TutorSearchScreen({super.key, required this.studentId});

  @override
  State<TutorSearchScreen> createState() => _TutorSearchScreenState();
}

class _TutorSearchScreenState extends State<TutorSearchScreen> {
  late final TutorSearchController _controller;
  final _nameController = TextEditingController();

  // Active filter values
  double _minRating = 0.0;
  String _locationType = 'all';

  // WHY StreamSubscription over polling?
  // connectivity_plus pushes change events from the OS network stack via a
  // broadcast stream. Polling with a Timer would wake the CPU every N seconds
  // regardless of whether the state changed, draining battery and adding
  // latency. A StreamSubscription costs zero CPU between events and delivers
  // the transition within milliseconds of it happening.
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _isOffline = false;

  // WHY 400 ms debounce?
  // Average human typing speed is ~200 ms per keystroke. A 400 ms window
  // swallows the gap between two keystrokes in a normal typing burst, so the
  // search fires once after the user pauses — not once per character. Shorter
  // than 300 ms and fast typists trigger mid-word fetches; longer than 600 ms
  // and the UI feels sluggish.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TutorSearchController(
      TutorSearchRepositoryImpl(ApiClient()),
    );
    _controller.addListener(_onUpdate);

    // WHY StreamSubscription stored as a field?
    // We must cancel it in dispose() to avoid the subscription calling setState
    // on a dead widget tree. Storing it as a field makes that cancel easy and
    // explicit, and ensures only one subscription is ever active at a time.
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Seed offline state from the current connectivity snapshot.
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(
        () => _isOffline =
            results.isEmpty || results.every((r) => r == ConnectivityResult.none),
      );
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final nowOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    final wasOffline = _isOffline;

    if (mounted) setState(() => _isOffline = nowOffline);

    // On reconnect, silently re-run the last search so results refresh without
    // requiring the user to tap Search again.
    if (wasOffline && !nowOffline) {
      _controller.replayLastSearch();
    }
  }

  void _onSearchChanged(String value) {
    // Cancel any pending debounce timer before scheduling a new one so only
    // the final keystroke in a burst triggers the search.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch();
    });
  }

  void _runSearch() {
    final courseId = _nameController.text.trim();
    if (courseId.isEmpty) return;

    _controller.search(
      courseId: courseId,
      minRating: _minRating,
      locationType: _locationType,
    );
  }

  void _openBookingSheet(AvailableTutorModel tutor) async {
    final courseId = _nameController.text.trim();
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingBottomSheet(
        tutor: tutor.toEntity(),
        studentId: widget.studentId,
        courseId: courseId,
        bookingSource: 'tutor_search',
        onBooked: () {
          // Invalidate cache for this course after a successful booking so the
          // next search fetches fresh availability from the server.
          _controller.invalidateForCourse(courseId);
        },
      ),
    );
    if (booked == true && mounted) setState(() {});
  }

  void _openAutoAssign() {
    final top = _controller.topRatedWithEarliestSlot;
    if (top == null) return;
    _openBookingSheet(top);
  }

  Future<void> _showRatingSheet() async {
    final chosen = await showModalBottomSheet<double>(
      context: context,
      builder: (_) => _FilterSheet(
        title: 'Minimum Rating',
        options: const ['Any', '3.0+', '4.0+', '4.5+'],
        values: const [0.0, 3.0, 4.0, 4.5],
        currentValue: _minRating,
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _minRating = chosen);
      _runSearch();
    }
  }

  Future<void> _showLocationSheet() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _FilterSheetString(
        title: 'Location',
        options: const ['Any', 'Virtual', 'On Campus'],
        values: const ['all', 'virtual', 'campus'],
        currentValue: _locationType,
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _locationType = chosen);
      _runSearch();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    _nameController.dispose();
    // Cancel debounce timer to avoid firing after the widget is unmounted.
    _debounce?.cancel();
    // Cancel connectivity subscription to prevent setState on a dead widget.
    _connectivitySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Center(
                child: Text(
                  'Tutors',
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),

            // ── Offline banner ───────────────────────────────────────────────
            if (_isOffline)
              Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Offline — showing saved results',
                  style: AppTextStyles.itemSubtitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Search bar ──────────────────────────────────────────────────
            Padding(
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
                      child: const Icon(
                        Icons.search,
                        color: AppColors.brown,
                        size: 24,
                      ),
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
                          controller: _nameController,
                          enabled: !_isOffline,
                          onChanged: _onSearchChanged,
                          style: AppTextStyles.searchHint,
                          decoration: InputDecoration(
                            hintText: 'Tutor name',
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
            ),

            // ── Filter chips ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Price',
                      enabled: !_isOffline,
                      onTap: () {/* price filter: future sprint */},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Location',
                      enabled: !_isOffline,
                      active: _locationType != 'all',
                      onTap: _isOffline ? null : _showLocationSheet,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Course',
                      enabled: !_isOffline,
                      onTap: () {/* course picker: future sprint */},
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Rating',
                      enabled: !_isOffline,
                      active: _minRating > 0,
                      onTap: _isOffline ? null : _showRatingSheet,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Auto-Assign row ─────────────────────────────────────────────
            if (_controller.status == SearchStatus.success &&
                _controller.tutors.isNotEmpty)
              InkWell(
                onTap: _openAutoAssign,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Auto-Assign',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Tutor list / state views ────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_controller.status == SearchStatus.idle) {
      return Center(
        child: Text(
          'Search for a tutor by name or course',
          style: AppTextStyles.itemSubtitle,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_isOffline && _controller.tutors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.brown),
              const SizedBox(height: 12),
              Text(
                'No internet — search unavailable offline',
                style: AppTextStyles.itemSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _runSearch,
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

    if (_controller.status == SearchStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.brown),
              const SizedBox(height: 12),
              Text(
                _controller.error ?? 'Something went wrong',
                style: AppTextStyles.itemSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _runSearch,
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

    if (_controller.tutors.isEmpty) {
      return Center(
        child: Text(
          'No tutors found — try different filters',
          style: AppTextStyles.itemSubtitle,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _controller.tutors.length,
      itemBuilder: (context, index) {
        final tutor = _controller.tutors[index];
        return _TutorRow(
          tutor: tutor,
          onTap: () => _openBookingSheet(tutor),
        );
      },
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    this.enabled = true,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.brown,
          ),
        ),
      ),
    );
  }
}

class _TutorRow extends StatelessWidget {
  final AvailableTutorModel tutor;
  final VoidCallback onTap;

  const _TutorRow({required this.tutor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = tutor.name.isNotEmpty ? tutor.name[0].toUpperCase() : '?';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Circular avatar with first letter of name
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: Text(
                initial,
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(tutor.name, style: AppTextStyles.itemTitle),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  tutor.rating.toStringAsFixed(1),
                  style: AppTextStyles.itemSubtitle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic filter bottom sheets ───────────────────────────────────────────

class _FilterSheet<T> extends StatelessWidget {
  final String title;
  final List<String> options;
  final List<T> values;
  final T currentValue;

  const _FilterSheet({
    required this.title,
    required this.options,
    required this.values,
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          ...List.generate(options.length, (i) {
            final selected = values[i] == currentValue;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(options[i], style: AppTextStyles.itemTitle),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, values[i]),
            );
          }),
        ],
      ),
    );
  }
}

// ignore: avoid_implementing_value_types
class _FilterSheetString extends _FilterSheet<String> {
  const _FilterSheetString({
    required super.title,
    required super.options,
    required super.values,
    required super.currentValue,
  });
}
