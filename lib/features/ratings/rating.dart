import '../../core/formatting.dart';
import '../../core/widgets.dart';

/// US-38: where rating one consultation stands for its owner (`my_consultation_rating`).
enum RatingState {
  /// The owner can rate it until [ConsultationRating.closesAt].
  available,

  /// The owner already rated it (once only).
  rated,

  /// The 14 days after the consultation have passed.
  closed,

  /// Cancelled, or the outcome is not documented yet.
  unavailable;

  static RatingState parse(Object? raw) => values.firstWhere((s) => s.name == raw, orElse: () => unavailable);
}

/// The longest comment the server accepts.
const maxRatingComment = 300;

class ConsultationRating {
  const ConsultationRating({required this.state, this.stars, this.comment, this.ratedAt, this.closesAt});

  final RatingState state;
  final int? stars;
  final String? comment;
  final DateTime? ratedAt;
  final DateTime? closesAt;

  factory ConsultationRating.fromMap(Map<String, dynamic> m) => ConsultationRating(
        state: RatingState.parse(m['state']),
        stars: (m['stars'] as num?)?.toInt(),
        comment: m['comment'] as String?,
        ratedAt: parseTsOrNull(m['rated_at']),
        closesAt: parseTsOrNull(m['closes_at']),
      );
}

/// One comment on a veterinarian's profile, with only the owner's first name.
class VetReview {
  const VetReview({required this.stars, required this.comment, required this.ownerFirstName, required this.ratedAt});

  final int stars;
  final String comment;
  final String ownerFirstName;
  final DateTime ratedAt;

  factory VetReview.fromMap(Map<String, dynamic> m) => VetReview(
        stars: (m['stars'] as num).toInt(),
        comment: m['comment'] as String? ?? '',
        ownerFirstName: m['owner_first_name'] as String? ?? '',
        ratedAt: parseTs(m['rated_at']),
      );
}

/// The codes `rate_consultation` raises, in the app's words.
const ratingErrors = {
  'already_rated': 'قيّمت هذه الاستشارة من قبل.',
  'rating_closed': 'انتهت مدة التقييم (١٤ يوماً بعد الاستشارة).',
  'outcome_not_documented': 'يمكنك التقييم بعد أن يوثّق الطبيب نتيجة الاستشارة.',
  'appointment_cancelled': 'لا يمكن تقييم موعد ملغى.',
  'not_your_consultation': 'هذه الاستشارة ليست في حسابك.',
  'bad_stars': 'اختر من نجمة إلى خمس نجوم.',
  'comment_too_long': 'التعليق طويل، الحد ٣٠٠ حرف.',
};

/// «تقييم واحد»، «تقييمان»، «٣ تقييمات»، «١٢ تقييماً».
String ratingCountLabel(int n) {
  if (n == 1) return 'تقييم واحد';
  if (n == 2) return 'تقييمان';
  final mod100 = n % 100;
  if (mod100 >= 3 && mod100 <= 10) return '${arabicDigits(n)} تقييمات';
  return '${arabicDigits(n)} تقييماً';
}
