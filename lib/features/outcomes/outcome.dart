class Outcome {
  const Outcome({
    required this.appointmentId,
    required this.caseId,
    required this.animalId,
    required this.consultationDate,
    required this.findings,
    required this.guidance,
    this.caseNumber,
    this.animalName,
    this.vetName,
    this.ownerNotes,
  });

  final String appointmentId;
  final String caseId;
  final String animalId;
  final DateTime consultationDate;
  final String findings;
  final String guidance;
  final String? caseNumber;
  final String? animalName;
  final String? vetName;
  final String? ownerNotes;

  factory Outcome.fromMap(Map<String, dynamic> m) => Outcome(
        appointmentId: m['appointment_id'] as String,
        caseId: m['case_id'] as String,
        animalId: m['animal_id'] as String,
        consultationDate: DateTime.parse(m['consultation_date'] as String),
        findings: m['findings'] as String,
        guidance: m['guidance'] as String,
        caseNumber: m['case_number'] as String?,
        animalName: m['animal_name'] as String?,
        vetName: m['vet_name'] as String?,
        ownerNotes: m['owner_notes'] as String?,
      );
}

class Referral {
  const Referral({required this.reason, required this.instructions, required this.createdAt});

  final String reason;
  final String instructions;
  final DateTime createdAt;

  factory Referral.fromMap(Map<String, dynamic> m) => Referral(
        reason: m['reason'] as String,
        instructions: m['instructions'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
