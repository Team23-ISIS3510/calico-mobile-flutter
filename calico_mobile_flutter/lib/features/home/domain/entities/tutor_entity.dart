class TutorEntity {
  final String id;
  final String name;
  final double rating;
  final double? hourlyRate;
  final String? profileImage;
  final String location;
  final DateTime? nextSlotStart;
  final DateTime? nextSlotEnd;
  final String? parentAvailabilityId;
  final int? nextSlotIndex;
  final int availableSlotsCount;
  final int? bookingCount;

  const TutorEntity({
    required this.id,
    required this.name,
    required this.rating,
    this.hourlyRate,
    this.profileImage,
    required this.location,
    this.nextSlotStart,
    this.nextSlotEnd,
    this.parentAvailabilityId,
    this.nextSlotIndex,
    required this.availableSlotsCount,
    this.bookingCount,
  });
}
