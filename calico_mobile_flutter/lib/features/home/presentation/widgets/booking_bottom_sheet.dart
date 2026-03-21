import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/available_tutor_model.dart';

class BookingBottomSheet extends StatefulWidget {
  final AvailableTutorModel tutor;
  final String studentId;
  final String courseId;

  const BookingBottomSheet({
    super.key,
    required this.tutor,
    required this.studentId,
    required this.courseId,
  });

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  bool _isLoading = false;
  bool _booked = false;
  String? _error;

  String _formatSlot() {
    final start = widget.tutor.nextSlotStart;
    final end = widget.tutor.nextSlotEnd;
    if (start == null) return 'No slot available';

    String fmt(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
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
      day = '${start.month}/${start.day}/${start.year}';
    }

    if (end != null) return '$day  ${fmt(start)} – ${fmt(end)}';
    return '$day  ${fmt(start)}';
  }

  Future<void> _bookNow() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ApiClient();
      await client.post(
        '/tutoring-sessions',
        body: {
          'tutorId': widget.tutor.id,
          'studentId': widget.studentId,
          'courseId': widget.courseId,
          'scheduledStart': widget.tutor.nextSlotStart!.toIso8601String(),
          'scheduledEnd': widget.tutor.nextSlotEnd!.toIso8601String(),
          'location': widget.tutor.location,
          'requiresApproval': false,
          if (widget.tutor.parentAvailabilityId != null)
            'parentAvailabilityId': widget.tutor.parentAvailabilityId,
          if (widget.tutor.nextSlotIndex != null)
            'slotIndex': widget.tutor.nextSlotIndex,
        },
      );
      setState(() {
        _isLoading = false;
        _booked = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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
          const SizedBox(height: 20),

          if (_booked) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            Text(
              'Booking confirmed!',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Your session with ${widget.tutor.name} has been booked.',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemSubtitle,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text('Done', style: AppTextStyles.buttonLabel),
            ),
          ] else ...[
            // Tutor info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tutor.name, style: AppTextStyles.itemTitle),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.tutor.rating.toStringAsFixed(1),
                          style: AppTextStyles.itemSubtitle,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.tutor.location,
                          style: AppTextStyles.itemSubtitle,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Slot info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next available slot',
                    style: AppTextStyles.itemSubtitle,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_formatSlot(), style: AppTextStyles.itemTitle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Price
            if (widget.tutor.hourlyRate != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Price', style: AppTextStyles.itemSubtitle),
                    Text(
                      '\$${widget.tutor.hourlyRate!.toStringAsFixed(0)}/hr',
                      style: AppTextStyles.itemTitle,
                    ),
                  ],
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.errorText,
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // Book button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFFCC06C),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black54,
                        ),
                      )
                    : Text('Book Now', style: AppTextStyles.buttonLabel),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
