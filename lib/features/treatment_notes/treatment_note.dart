import '../../core/formatting.dart';

/// US-37: one prescribed medicine. Every field is required; the veterinarian writes them all (nothing is suggested or
/// filled in by the AI).
class Medicine {
  const Medicine({required this.name, required this.dose, required this.frequency, required this.duration});

  final String name;
  final String dose;
  final String frequency;
  final String duration;

  factory Medicine.fromMap(Map<String, dynamic> m) => Medicine(
        name: m['name'] as String? ?? '',
        dose: m['dose'] as String? ?? '',
        frequency: m['frequency'] as String? ?? '',
        duration: m['duration'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'name': name.trim(), 'dose': dose.trim(), 'frequency': frequency.trim(), 'duration': duration.trim()};

  /// The labels of the fields still empty, in form order. Empty when the medicine is complete.
  List<String> get missing => [
        if (name.trim().isEmpty) medicineFieldLabels[0],
        if (dose.trim().isEmpty) medicineFieldLabels[1],
        if (frequency.trim().isEmpty) medicineFieldLabels[2],
        if (duration.trim().isEmpty) medicineFieldLabels[3],
      ];
}

const medicineFieldLabels = ['اسم الدواء', 'الجرعة', 'عدد المرات', 'المدة'];

/// Why a note cannot be issued yet, or null when it can: every medicine needs all four fields, and a note needs care
/// instructions, a medicine, or both.
String? noteProblem(String instructions, List<Medicine> medicines) {
  for (var i = 0; i < medicines.length; i++) {
    final missing = medicines[i].missing;
    if (missing.isNotEmpty) return 'أكمل الدواء ${i + 1}: ${missing.join('، ')}.';
  }
  if (instructions.trim().isEmpty && medicines.isEmpty) {
    return 'اكتب تعليمات العناية أو أضف دواءً واحداً على الأقل.';
  }
  return null;
}

/// The codes `issue_treatment_note` raises, in the app's words.
const treatmentNoteErrors = {
  'not_responsible_vet': 'هذه الاستشارة ليست لك، فلا يمكنك إصدار ملاحظة لها.',
  'consultation_not_started': 'تصدر ملاحظة العلاج بعد إجراء الاستشارة.',
  'medicine_incomplete': 'أكمل اسم كل دواء وجرعته وعدد مراته ومدته.',
  'note_empty': 'اكتب تعليمات العناية أو أضف دواءً واحداً على الأقل.',
  'bad_correction': 'الملاحظة التي تصححها ليست من هذه الاستشارة.',
  'bad_medicines': 'قائمة الأدوية غير صالحة (الحد ٢٠ دواءً).',
};

/// An issued note, as `treatment_notes_for` returns it. Final: it is never edited, only corrected by a new note.
class TreatmentNote {
  const TreatmentNote({
    required this.id,
    required this.appointmentId,
    required this.vetName,
    required this.licenseNumber,
    required this.issuedAt,
    this.careInstructions,
    this.correctsNoteId,
    this.medicines = const [],
  });

  final String id;
  final String appointmentId;
  final String vetName;
  final String licenseNumber;
  final DateTime issuedAt;
  final String? careInstructions;

  /// The earlier note this one corrects; both stay in the record.
  final String? correctsNoteId;
  final List<Medicine> medicines;

  factory TreatmentNote.fromMap(Map<String, dynamic> m) => TreatmentNote(
        id: m['id'] as String,
        appointmentId: m['appointment_id'] as String,
        vetName: m['vet_name'] as String? ?? '',
        licenseNumber: m['license_number'] as String? ?? '',
        issuedAt: parseTs(m['issued_at']),
        careInstructions: m['care_instructions'] as String?,
        correctsNoteId: m['corrects_note_id'] as String?,
        medicines: [for (final x in (m['medicines'] as List? ?? const [])) Medicine.fromMap(x as Map<String, dynamic>)],
      );
}

/// The notes a later note corrects (they are shown as replaced).
Set<String> correctedNoteIds(Iterable<TreatmentNote> notes) => {for (final n in notes) ?n.correctsNoteId};
