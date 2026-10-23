import '../../core/supabase.dart';
import 'outcome.dart';

class OutcomesRepository {
  Future<List<Outcome>> forAnimal(String animalId) async {
    final rows = await db.rpc('owner_outcomes', params: {'p_animal': animalId}) as List;
    return rows.map((r) => Outcome.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Null until the veterinarian has approved the outcome.
  Future<Outcome?> forAppointment(String appointmentId) async {
    final rows = await db.rpc('owner_outcomes', params: {'p_appointment': appointmentId}) as List;
    return rows.isEmpty ? null : Outcome.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<List<Referral>> referralsForCase(String caseId) async {
    final rows = await db.from('referrals').select().eq('case_id', caseId).order('created_at');
    return rows.map(Referral.fromMap).toList();
  }
}
