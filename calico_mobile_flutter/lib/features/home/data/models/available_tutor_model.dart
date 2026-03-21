class AvailableTutorModel {
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

  const AvailableTutorModel({
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

  factory AvailableTutorModel.fromJson(Map<String, dynamic> json) {
    final slot = json['nextAvailableSlot'] as Map<String, dynamic>?;
    return AvailableTutorModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
      profileImage: json['profileImage']?.toString(),
      location: json['location']?.toString() ?? 'Virtual',
      nextSlotStart: slot?['startDateTime'] != null
          ? DateTime.tryParse(slot!['startDateTime'].toString())
          : null,
      nextSlotEnd: slot?['endDateTime'] != null
          ? DateTime.tryParse(slot!['endDateTime'].toString())
          : null,
      parentAvailabilityId: slot?['parentAvailabilityId']?.toString(),
      nextSlotIndex: (slot?['slotIndex'] as num?)?.toInt(),
      availableSlotsCount: (json['availableSlotsCount'] as num?)?.toInt() ?? 0,
      bookingCount: (json['bookingCount'] as num?)?.toInt(),
    );
  }
}
