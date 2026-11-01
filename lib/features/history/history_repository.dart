import '../../core/supabase.dart';
import 'consultation_history.dart';

/// The codes `animal_history` and `consultation_record` raise, in the app's words.
const historyErrors = {
  'animal_not_found': 'لم نجد هذا الحيوان في حسابك.',
  'record_not_found': 'لم نجد هذه الاستشارة في سجلك.',
};

/// US-22, US-23: the owner's read-only consultation history.
class HistoryRepository {
  /// The animal's consultations, newest first; empty when it has none.
  Future<List<HistoryEntry>> forAnimal(String animalId) async {
    final rows = (await db.rpc('animal_history', params: {'p_animal': animalId}) as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];
    final genders = await _vetGenders();
    return newestFirst(rows.map((r) => HistoryEntry.fromMap(r, vetGender: genders[r['appointment_id']])));
  }

  /// One past consultation, with the veterinarian's gender for the avatar.
  Future<(ConsultationRecord, String?)> record(String appointmentId) async {
    final rows = await db.rpc('consultation_record', params: {'p_appointment': appointmentId}) as List;
    if (rows.isEmpty) throw StateError('record_not_found');
    final genders = await _vetGenders(appointmentId);
    return (ConsultationRecord.fromMap(rows.first as Map<String, dynamic>), genders[appointmentId]);
  }

  /// The history functions do not return the veterinarian's gender; the owner's appointments (US-11) do.
  /// Best effort: without it the avatar is neutral.
  Future<Map<String, String?>> _vetGenders([String? appointmentId]) async {
    try {
      final rows = await db.rpc(
        'my_appointments',
        params: appointmentId == null ? null : {'p_appointment': appointmentId},
      ) as List;
      return {for (final r in rows.cast<Map<String, dynamic>>()) r['id'] as String: r['vet_gender'] as String?};
    } catch (_) {
      return const {};
    }
  }
}
