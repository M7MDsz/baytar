import '../../core/catalog.dart';

class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.sex,
    this.breed,
    this.birthDate,
    this.ageYears,
    this.weightKg,
    this.photoPath,
    this.conditions,
    this.allergies,
  });

  final String id;
  final String name;
  final String species;
  final String sex;
  final String? breed;
  final DateTime? birthDate;
  final double? ageYears;
  final double? weightKg;
  final String? photoPath;
  final String? conditions;
  final String? allergies;

  String get speciesLabel => label(speciesLabels, species);
  String get sexLabel => label(sexLabels, sex);

  /// Age in years from the date of birth when known, otherwise the entered age.
  String get ageLabel {
    if (birthDate != null) {
      final days = DateTime.now().difference(birthDate!).inDays;
      if (days < 365) return '${(days / 30).floor()} شهر';
      return '${(days / 365).floor()} سنة';
    }
    if (ageYears == null) return '';
    final a = ageYears!;
    return '${a == a.roundToDouble() ? a.toInt() : a} سنة';
  }

  factory Animal.fromMap(Map<String, dynamic> m) => Animal(
        id: m['id'] as String,
        name: m['name'] as String,
        species: m['species'] as String,
        sex: m['sex'] as String,
        breed: m['breed'] as String?,
        birthDate: m['birth_date'] == null ? null : DateTime.parse(m['birth_date'] as String),
        ageYears: (m['age_years'] as num?)?.toDouble(),
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        photoPath: m['photo_path'] as String?,
        conditions: m['conditions'] as String?,
        allergies: m['allergies'] as String?,
      );
}
