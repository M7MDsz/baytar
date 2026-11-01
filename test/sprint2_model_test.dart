import 'package:baytar/features/case_summary/model/case_summary.dart';
import 'package:baytar/features/voice/model/transcript_label.dart';
import 'package:flutter_test/flutter_test.dart';

// Sprint 2 shared data model: the shapes the US-36, US-24 and US-25/27/28 screens read from the database.
void main() {
  group('transcript label', () {
    test('reads every database value and treats anything else as no recording', () {
      expect(TranscriptLabel.parse('auto'), TranscriptLabel.auto);
      expect(TranscriptLabel.parse('owner'), TranscriptLabel.owner);
      expect(TranscriptLabel.parse('pending'), TranscriptLabel.pending);
      expect(TranscriptLabel.parse('unavailable'), TranscriptLabel.unavailable);
      expect(TranscriptLabel.parse(null), TranscriptLabel.none);
      expect(TranscriptLabel.parse('something_new'), TranscriptLabel.none);
    });

    test('shows the agreed Arabic labels', () {
      expect(TranscriptLabel.auto.text, 'نص تلقائي');
      expect(TranscriptLabel.owner.text, 'عدّله المالك');
      expect(TranscriptLabel.auto.hasText, isTrue);
      expect(TranscriptLabel.unavailable.hasText, isFalse);
    });
  });

  group('summary status', () {
    test('reads every database value; null means no summary was requested', () {
      expect(SummaryStatus.parse('pending'), SummaryStatus.pending);
      expect(SummaryStatus.parse('generated'), SummaryStatus.generated);
      expect(SummaryStatus.parse('not_generated'), SummaryStatus.notGenerated);
      expect(SummaryStatus.parse('failed'), SummaryStatus.failed);
      expect(SummaryStatus.parse('accepted'), SummaryStatus.accepted);
      expect(SummaryStatus.parse('disregarded'), SummaryStatus.disregarded);
      expect(SummaryStatus.parse(null), SummaryStatus.none);
    });

    test('only a generated or accepted summary has content, and only a generated one can be reviewed', () {
      expect(SummaryStatus.values.where((s) => s.hasContent), [SummaryStatus.generated, SummaryStatus.accepted]);
      expect(SummaryStatus.values.where((s) => s.awaitingReview), [SummaryStatus.generated]);
      expect(SummaryStatus.disregarded.hasContent, isFalse);
    });
  });

  group('summary content', () {
    test('reads the {value, quote} items and the symptom list', () {
      final c = SummaryContent.fromJson({
        'chief_complaint': {'value': 'حكة في الأذن', 'quote': 'تحك أذنها'},
        'duration': {'value': 'منذ ثلاثة أيام', 'quote': 'من ثلاث أيام'},
        'onset': null,
        'affected_area': {'value': 'الأذن اليسرى', 'quote': 'أذنها اليسار'},
        'symptoms': [
          {'value': 'حكة', 'quote': 'تحك'},
          {'value': 'هز الرأس', 'quote': 'تهز راسها'},
        ],
      })!;
      expect(c.chiefComplaint!.value, 'حكة في الأذن');
      expect(c.chiefComplaint!.quote, 'تحك أذنها');
      expect(c.duration!.value, 'منذ ثلاثة أيام');
      expect(c.onset, isNull);
      expect(c.affectedArea!.value, 'الأذن اليسرى');
      expect(c.symptoms.map((s) => s.value), ['حكة', 'هز الرأس']);
      expect(c.isEmpty, isFalse);
    });

    test('drops malformed items instead of failing', () {
      final c = SummaryContent.fromJson({
        'chief_complaint': 'not an object',
        'duration': {'value': '   ', 'quote': 'x'},
        'symptoms': [
          {'value': 'عرج'},
          {'quote': 'no value'},
          42,
        ],
      })!;
      expect(c.chiefComplaint, isNull);
      expect(c.duration, isNull);
      expect(c.symptoms.single.value, 'عرج');
      expect(c.symptoms.single.quote, isNull);
    });

    test('no content for null, non-objects and broken JSON; a JSON string is read', () {
      expect(SummaryContent.fromJson(null), isNull);
      expect(SummaryContent.fromJson(const [1, 2]), isNull);
      expect(SummaryContent.fromJson('{broken'), isNull);
      expect(SummaryContent.fromJson('{"symptoms":[{"value":"قيء","quote":"ترجع"}]}')!.symptoms.single.value, 'قيء');
      expect(SummaryContent.fromJson(const {})!.isEmpty, isTrue);
    });
  });
}
