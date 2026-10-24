import '../../core/formatting.dart';

class OwnerAppointment {
  const OwnerAppointment({
    required this.id,
    required this.caseId,
    required this.animalName,
    required this.vetId,
    required this.vetName,
    required this.startsAt,
    required this.status,
    required this.hasOutcome,
    this.caseNumber,
    this.endedAt,
  });

  final String id;
  final String caseId;
  final String? caseNumber;
  final String animalName;
  final String vetId;
  final String vetName;
  final DateTime startsAt;

  /// booked, cancelled or completed.
  final String status;
  final DateTime? endedAt;
  final bool hasOutcome;

  bool get isUpcoming => status == 'booked' && endedAt == null && startsAt.add(const Duration(minutes: 30)).isAfter(DateTime.now());

  String get statusLabel => switch (status) {
        'cancelled' => 'ملغى',
        'completed' => 'مكتمل',
        _ => isUpcoming ? 'قادم' : 'انتهى',
      };

  factory OwnerAppointment.fromMap(Map<String, dynamic> m) => OwnerAppointment(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        caseNumber: m['case_number'] as String?,
        animalName: m['animal_name'] as String,
        vetId: m['vet_id'] as String,
        vetName: m['vet_name'] as String,
        startsAt: parseTs(m['starts_at']),
        status: m['status'] as String,
        endedAt: parseTsOrNull(m['ended_at']),
        hasOutcome: m['has_outcome'] as bool,
      );
}
