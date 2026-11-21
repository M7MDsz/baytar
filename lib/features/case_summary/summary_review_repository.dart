import '../../core/supabase.dart';
import 'model/case_summary.dart';
import 'summary_review.dart';

/// US-25, US-27, US-28: the assigned veterinarian's comparison view and decision.
class SummaryReviewRepository {
  Future<VetCaseSummary> load(String caseId) async {
    final rows = await db.rpc('vet_case_summary', params: {'p_case': caseId}) as List;
    if (rows.isEmpty) throw StateError('not_assigned');
    return VetCaseSummary.fromRow(rows.first as Map<String, dynamic>);
  }

  /// Accepts or disregards a generated summary, once. Returns the stored status.
  Future<SummaryStatus> review(String caseId, ReviewAction action) async =>
      SummaryStatus.parse(await db.rpc('review_summary', params: {'p_case': caseId, 'p_action': action.name}));
}
