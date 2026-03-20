class AvailableTutorModel {
  final String id;
  final String name;
  final double rating;
  final double? hourlyRate;
  final String? profileImage;
  final String location;
  final DateTime? nextSlotStart;
  final DateTime? nextSlotEnd;
  final int availableSlotsCount;

  const AvailableTutorModel({
    required this.id,
    required this.name,
    required this.rating,
    this.hourlyRate,
    this.profileImage,
    required this.location,
    this.nextSlotStart,
    this.nextSlotEnd,
    required this.availableSlotsCount,
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
      availableSlotsCount:
          (json['availableSlotsCount'] as num?)?.toInt() ?? 0,
    );
  }
}
