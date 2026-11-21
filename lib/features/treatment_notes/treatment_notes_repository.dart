import '../../core/supabase.dart';
import 'treatment_note.dart';

/// US-37: the treatment notes of one consultation, for its owner and its veterinarian.
class TreatmentNotesRepository {
  /// Oldest first; empty when there are none (or the caller is not part of the consultation).
  Future<List<TreatmentNote>> forAppointment(String appointmentId) async {
    final rows = await db.rpc('treatment_notes_for', params: {'p_appointment': appointmentId}) as List;
    return rows.map((r) => TreatmentNote.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Issues a note (final once issued). [corrects] is the earlier note of the same consultation it corrects.
  Future<String> issue({
    required String appointmentId,
    required String instructions,
    required List<Medicine> medicines,
    String? corrects,
  }) async =>
      await db.rpc('issue_treatment_note', params: {
        'p_appointment': appointmentId,
        'p_care_instructions': instructions.trim(),
        'p_medicines': [for (final m in medicines) m.toJson()],
        'p_corrects': corrects,
      }) as String;
}
