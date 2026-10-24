import '../../core/formatting.dart';

List<String> _strings(Object? v) => [for (final x in (v as List? ?? const [])) x as String];

class VetSummary {
  const VetSummary({
    required this.id,
    required this.fullName,
    required this.specialties,
    required this.animalTypes,
    required this.languages,
    this.nextAvailable,
  });

  final String id;
  final String fullName;
  final List<String> specialties;
  final List<String> animalTypes;
  final List<String> languages;
  final DateTime? nextAvailable;

  /// A veterinarian with no free time cannot be chosen for a new booking.
  bool get bookable => nextAvailable != null;

  factory VetSummary.fromMap(Map<String, dynamic> m) => VetSummary(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        specialties: _strings(m['specialties']),
        animalTypes: _strings(m['animal_types']),
        languages: _strings(m['languages']),
        nextAvailable: parseTsOrNull(m['next_available']),
      );
}

class VetProfile extends VetSummary {
  const VetProfile({
    required super.id,
    required super.fullName,
    required super.specialties,
    required super.animalTypes,
    required super.languages,
    required this.licenseNumber,
    required this.licenseExpiry,
    super.nextAvailable,
    this.bio,
    this.rating,
  });

  final String licenseNumber;
  final DateTime licenseExpiry;
  final String? bio;
  final double? rating;

  factory VetProfile.fromMap(Map<String, dynamic> m) => VetProfile(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        specialties: _strings(m['specialties']),
        animalTypes: _strings(m['animal_types']),
        languages: _strings(m['languages']),
        nextAvailable: parseTsOrNull(m['next_available']),
        licenseNumber: m['license_number'] as String,
        licenseExpiry: DateTime.parse(m['license_expiry'] as String),
        bio: m['bio'] as String?,
        rating: (m['rating'] as num?)?.toDouble(),
      );
}

/// US-09 filters. Null means "any".
class VetFilters {
  const VetFilters({this.specialty, this.animalType, this.language, this.withinDays});

  final String? specialty;
  final String? animalType;
  final String? language;
  final int? withinDays;

  bool get isEmpty => specialty == null && animalType == null && language == null && withinDays == null;

  Map<String, dynamic> toParams() => {
        'p_specialty': specialty,
        'p_animal_type': animalType,
        'p_language': language,
        'p_within_days': withinDays,
      };
}
