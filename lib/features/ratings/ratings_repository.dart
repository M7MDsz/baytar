import '../../core/supabase.dart';
import 'rating.dart';

/// US-38: rating a consultation, and the comments on a veterinarian's profile.
class RatingsRepository {
  /// Null when the consultation is not the caller's.
  Future<ConsultationRating?> mine(String appointmentId) async {
    final rows = await db.rpc('my_consultation_rating', params: {'p_appointment': appointmentId}) as List;
    return rows.isEmpty ? null : ConsultationRating.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> rate(String appointmentId, int stars, String comment) => db.rpc('rate_consultation', params: {
        'p_appointment': appointmentId,
        'p_stars': stars,
        'p_comment': comment.trim().isEmpty ? null : comment.trim(),
      });

  /// Newest first, with the owner's first name only.
  Future<List<VetReview>> reviews(String vetId) async {
    final rows = await db.rpc('vet_reviews', params: {'p_vet': vetId}) as List;
    return rows.map((r) => VetReview.fromMap(r as Map<String, dynamic>)).toList();
  }
}
