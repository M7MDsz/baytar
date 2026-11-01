import 'package:intl/intl.dart';

import '../../core/formatting.dart';

/// US-22: one consultation in an animal's history, as `animal_history` returns it.
class HistoryEntry {
  const HistoryEntry({
    required this.appointmentId,
    required this.caseId,
    required this.startsAt,
    required this.vetName,
    required this.outcomeApproved,
    this.caseNumber,
    this.vetGender,
  });

  final String appointmentId;
  final String caseId;
  final String? caseNumber;
  final DateTime startsAt;
  final String vetName;

  /// The owner can read the outcome only once the veterinarian approved it (US-16).
  final bool outcomeApproved;

  /// For the doctor avatar; null shows a neutral one.
  final String? vetGender;

  factory HistoryEntry.fromMap(Map<String, dynamic> m, {String? vetGender}) => HistoryEntry(
        appointmentId: m['appointment_id'] as String,
        caseId: m['case_id'] as String,
        caseNumber: m['case_number'] as String?,
        startsAt: parseTs(m['starts_at']),
        vetName: m['vet_name'] as String? ?? '',
        outcomeApproved: m['outcome_status'] == 'approved',
        vetGender: vetGender,
      );
}

/// US-23: one past consultation, as `consultation_record` returns it. Read-only.
class ConsultationRecord {
  const ConsultationRecord({
    required this.appointmentId,
    required this.caseId,
    required this.animalId,
    required this.animalName,
    required this.startsAt,
    required this.vetName,
    required this.hasVoice,
    required this.outcomeApproved,
    this.caseNumber,
    this.description,
    this.findings,
    this.guidance,
    this.ownerNotes,
    this.approvedAt,
    this.referralReason,
    this.referralInstructions,
    this.referredAt,
  });

  final String appointmentId;
  final String caseId;
  final String? caseNumber;
  final String animalId;
  final String animalName;
  final DateTime startsAt;
  final String vetName;
  final String? description;
  final bool hasVoice;
  final bool outcomeApproved;

  /// The documented outcome, only once approved.
  final String? findings;
  final String? guidance;
  final String? ownerNotes;
  final DateTime? approvedAt;

  final String? referralReason;
  final String? referralInstructions;
  final DateTime? referredAt;

  bool get hasReferral => (referralReason ?? '').trim().isNotEmpty;

  factory ConsultationRecord.fromMap(Map<String, dynamic> m) {
    final approved = m['outcome_status'] == 'approved';
    return ConsultationRecord(
      appointmentId: m['appointment_id'] as String,
      caseId: m['case_id'] as String,
      caseNumber: m['case_number'] as String?,
      animalId: m['animal_id'] as String,
      animalName: m['animal_name'] as String? ?? '',
      startsAt: parseTs(m['starts_at']),
      vetName: m['vet_name'] as String? ?? '',
      description: m['description'] as String?,
      hasVoice: m['has_voice'] == true,
      outcomeApproved: approved,
      findings: approved ? m['findings'] as String? : null,
      guidance: approved ? m['guidance'] as String? : null,
      ownerNotes: approved ? m['owner_notes'] as String? : null,
      approvedAt: approved ? parseTsOrNull(m['approved_at']) : null,
      referralReason: m['referral_reason'] as String?,
      referralInstructions: m['referral_instructions'] as String?,
      referredAt: parseTsOrNull(m['referred_at']),
    );
  }
}

/// Newest first. The database already orders them; sorting here keeps the screen right whatever it receives.
List<HistoryEntry> newestFirst(Iterable<HistoryEntry> entries) =>
    entries.toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));

/// «الاثنين 2 نوفمبر» within the current year, «2 نوفمبر 2025» for earlier years.
String historyDateLabel(DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final pattern = d.year == (now ?? DateTime.now()).toLocal().year ? 'EEEE d MMMM' : 'd MMMM y';
  return DateFormat(pattern, 'ar').format(d);
}

/// The veterinarian's name with the «د.» title, never twice.
String vetDisplayName(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'الطبيب';
  return n.startsWith('د.') || n.startsWith('د ') ? n : 'د. $n';
}

/// «استشارة واحدة», «استشارتان», «3 استشارات», «11 استشارة».
String consultationCountLabel(int n) => switch (n) {
      0 => 'لا توجد استشارات بعد',
      1 => 'استشارة واحدة',
      2 => 'استشارتان',
      _ when n % 100 >= 3 && n % 100 <= 10 => '$n استشارات',
      _ => '$n استشارة',
    };

/// The outcome pill: an approved outcome can be opened; otherwise it is still waiting for the veterinarian.
String outcomeStatusLabel(bool approved) => approved ? 'النتيجة معتمدة' : 'بانتظار النتيجة';

/// Shared by the history row's avatar and the record's header, so the avatar flies between them.
String consultationHeroTag(String appointmentId) => 'consultation-vet-$appointmentId';

String animalHistoryPath(String animalId) => '/animals/$animalId/history';

String consultationRecordPath(String animalId, String appointmentId) => '/animals/$animalId/history/$appointmentId';
