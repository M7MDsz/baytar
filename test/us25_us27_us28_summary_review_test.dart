import 'package:baytar/features/case_summary/model/case_summary.dart';
import 'package:baytar/features/case_summary/summary_review.dart';
import 'package:baytar/features/voice/model/transcript_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-25 Compare, US-27 Accept, US-28 Disregard: what the veterinarian's comparison view reads and shows.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  const content = {
    'chief_complaint': {'value': 'حك الأذن', 'quote': 'تحك أذنها'},
    'symptoms': [
      {'value': 'هز الرأس', 'quote': 'تهز راسها'},
    ],
  };

  Map<String, dynamic> row(String? status, {String label = 'auto', String? reviewer, String? at}) => {
        'case_id': 'c1',
        'description': 'لونا تحك أذنها وتهز راسها',
        'voice_path': 'u/c1/v.m4a',
        'transcript': 'لونا تحك أذنها',
        'transcript_label': label,
        'summary_status': status,
        'summary_content': content,
        'reviewed_by_name': reviewer,
        'reviewed_at': at,
      };

  group('the comparison', () {
    test('keeps the original description and the labelled transcript next to the summary', () {
      final s = VetCaseSummary.fromRow(row('generated'));
      expect(s.description, 'لونا تحك أذنها وتهز راسها');
      expect(s.voicePath, 'u/c1/v.m4a');
      expect(s.transcript, 'لونا تحك أذنها');
      expect(s.transcriptLabel, TranscriptLabel.auto);
      expect(s.status, SummaryStatus.generated);
      expect(s.content!.chiefComplaint!.value, 'حك الأذن');
    });

    test('a transcript that is not available is never shown as text', () {
      final s = VetCaseSummary.fromRow(row('generated', label: 'unavailable'));
      expect(s.transcript, isNull);
      expect(s.transcriptLabel.text, 'النص غير متاح');
    });

    test('a disregarded summary carries no content, so it can never be shown as accepted', () {
      final s = VetCaseSummary.fromRow(row('disregarded', reviewer: 'سارة العتيبي', at: '2026-11-02T18:40:00Z'));
      expect(s.content, isNull);
      expect(s.status.hasContent, isFalse);
    });

    test('a case sent before the AI was live has no summary status', () {
      final s = VetCaseSummary.fromRow(row(null)..['summary_content'] = null);
      expect(s.status, SummaryStatus.none);
      expect(s.content, isNull);
    });
  });

  group('the decision', () {
    test('the action names are the review_summary values', () {
      expect(ReviewAction.accept.name, 'accept');
      expect(ReviewAction.disregard.name, 'disregard');
    });

    test('says who decided and when', () {
      final at = DateTime(2026, 11, 2, 21, 40);
      expect(reviewCaption(SummaryStatus.accepted, 'سارة العتيبي', at), 'قبله د. سارة · 2 نوفمبر 9:40 م');
      expect(reviewCaption(SummaryStatus.disregarded, 'د. سارة العتيبي', at), startsWith('تجاهله د. سارة · '));
      expect(reviewCaption(SummaryStatus.generated, 'سارة', at), isNull);
      expect(reviewCaption(SummaryStatus.accepted, null, null), 'قبله الطبيب');
    });

    test('every error code of the two functions has Arabic text', () {
      expect(summaryReviewErrors.keys,
          containsAll(['already_reviewed', 'no_summary_to_review', 'not_assigned', 'bad_action']));
    });
  });
}
