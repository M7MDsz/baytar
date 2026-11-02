import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../voice/model/transcript_label.dart';
import 'model/case_summary.dart';

/// US-27 accept, US-28 disregard. The names are the `p_action` values of `review_summary`.
enum ReviewAction { accept, disregard }

/// The codes `vet_case_summary` and `review_summary` raise, in the app's words.
const summaryReviewErrors = {
  'already_reviewed': 'تمت مراجعة هذا الملخص من قبل.',
  'no_summary_to_review': 'لا يوجد ملخص بانتظار المراجعة.',
  'not_assigned': 'هذه الحالة غير مسندة إليك.',
  'bad_action': 'تعذّر تنفيذ هذا الإجراء.',
};

/// US-25: what `vet_case_summary` returns for one case: the owner's original description, the recording and its
/// transcript, next to the AI summary and the veterinarian's decision on it.
class VetCaseSummary {
  const VetCaseSummary({
    required this.transcriptLabel,
    required this.status,
    this.description,
    this.voicePath,
    this.transcript,
    this.content,
    this.reviewerName,
    this.reviewedAt,
  });

  /// The owner's original text, exactly as sent. Never replaced by the summary.
  final String? description;
  final String? voicePath;
  final String? transcript;
  final TranscriptLabel transcriptLabel;
  final SummaryStatus status;

  /// Only while generated or accepted: a disregarded summary has no content, so it can never be shown as accepted.
  final SummaryContent? content;
  final String? reviewerName;
  final DateTime? reviewedAt;

  factory VetCaseSummary.fromRow(Map<String, dynamic> m) {
    final status = SummaryStatus.parse(m['summary_status']);
    final label = TranscriptLabel.parse(m['transcript_label']);
    return VetCaseSummary(
      description: m['description'] as String?,
      voicePath: m['voice_path'] as String?,
      transcript: label.hasText ? m['transcript'] as String? : null,
      transcriptLabel: label,
      status: status,
      content: status.hasContent ? SummaryContent.fromJson(m['summary_content']) : null,
      reviewerName: m['reviewed_by_name'] as String?,
      reviewedAt: parseTsOrNull(m['reviewed_at']),
    );
  }
}

/// «د. سارة» from a full name; an existing «د.» is not repeated.
String doctorTitle(String? fullName) {
  final words = (fullName ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w != 'د.' && w != 'د');
  return words.isEmpty ? 'الطبيب' : 'د. ${words.first}';
}

/// After a decision: who made it and when, for example «قبله د. سارة · 2 نوفمبر 9:40 م». Null before one.
String? reviewCaption(SummaryStatus status, String? reviewerName, DateTime? reviewedAt) {
  if (!status.reviewed) return null;
  final verb = status == SummaryStatus.accepted ? 'قبله' : 'تجاهله';
  return [
    '$verb ${doctorTitle(reviewerName)}',
    if (reviewedAt != null) DateFormat('d MMMM h:mm a', 'ar').format(reviewedAt.toLocal()),
  ].join(' · ');
}
