import '../../core/catalog.dart';

class VetAppointment {
  const VetAppointment({
    required this.id,
    required this.caseId,
    required this.startsAt,
    required this.animalName,
    required this.species,
    required this.ownerFirstName,
  });

  final String id;
  final String caseId;
  final DateTime startsAt;
  final String animalName;
  final String species;
  final String ownerFirstName;

  String get speciesLabel => label(speciesLabels, species);

  factory VetAppointment.fromMap(Map<String, dynamic> m) => VetAppointment(
        id: m['appointment_id'] as String,
        caseId: m['case_id'] as String,
        startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
        animalName: m['animal_name'] as String,
        species: m['species'] as String,
        ownerFirstName: m['owner_first_name'] as String,
      );
}
