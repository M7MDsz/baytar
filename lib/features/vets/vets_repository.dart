import '../../core/supabase.dart';
import 'vet_summary.dart';

class VetsRepository {
  Future<List<VetSummary>> list(VetFilters filters) async {
    final rows = await db.rpc('list_vets', params: filters.toParams()) as List;
    return rows.map((r) => VetSummary.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Null when the veterinarian is not (or no longer) verified.
  Future<VetProfile?> profile(String vetId) async {
    final rows = await db.rpc('vet_public_profile', params: {'p_vet': vetId}) as List;
    return rows.isEmpty ? null : VetProfile.fromMap(rows.first as Map<String, dynamic>);
  }
}
