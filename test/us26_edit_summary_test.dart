import 'package:baytar/features/case_summary/model/case_summary.dart';
import 'package:baytar/features/case_summary/summary_card.dart';
import 'package:baytar/features/case_summary/summary_editor_screen.dart';
import 'package:baytar/features/case_summary/summary_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-26 Edit an AI-Structured Summary.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  const ai = {
    'chief_complaint': {'value': 'حك الأذن', 'quote': 'تحك أذنها'},
    'duration': {'value': 'ثلاثة أيام', 'quote': 'منذ ثلاثة أيام'},
    'symptoms': [
      {'value': 'هز الرأس', 'quote': 'تهز رأسها'},
    ],
  };
  const latest = {
    'chief_complaint': {'value': 'حكة في الأذن اليسرى', 'quote': 'تحك أذنها'},
    'symptoms': [
      {'value': 'هز الرأس', 'quote': 'تهز رأسها'},
      {'value': 'رائحة من الأذن', 'quote': null},
    ],
  };

  group('the edited state', () {
    test('an edited summary has content and still waits for Accept or Disregard', () {
      final s = SummaryStatus.parse('edited');
      expect(s, SummaryStatus.edited);
      expect(s.hasContent, isTrue);
      expect(s.awaitingReview, isTrue);
      expect(s.reviewed, isFalse);
    });

    test('its pill says the veterinarian edited it', () {
      expect(summaryReviewPill(SummaryStatus.edited)!.$1, 'عدّله الطبيب · بانتظار القرار');
    });
  });

  group('the case view after an edit', () {
    final row = {
      'case_id': 'c1',
      'description': 'لونا تحك أذنها منذ ثلاثة أيام وتهز رأسها',
      'transcript_label': null,
      'summary_status': 'edited',
      'summary_content': latest,
      'ai_content': ai,
      'edited_by_name': 'سارة القحطاني',
      'edited_at': '2026-11-12T18:40:00Z',
    };

    test('shows the latest saved version and keeps what the AI wrote', () {
      final s = VetCaseSummary.fromRow(row);
      expect(s.content!.chiefComplaint!.value, 'حكة في الأذن اليسرى');
      expect(s.aiContent!.chiefComplaint!.value, 'حك الأذن');
      expect(s.description, 'لونا تحك أذنها منذ ثلاثة أيام وتهز رأسها', reason: 'the original description never changes');
      expect(s.edited, isTrue);
    });

    test('says who edited it and that it still comes from the AI', () {
      final s = VetCaseSummary.fromRow(row);
      final caption = editCaption(s.editorName, s.editedAt)!;
      expect(caption, startsWith('عدّله د. سارة · '));
      expect(caption, endsWith('الأصل من الذكاء الاصطناعي'));
    });

    test('a summary that was never edited has no edit caption', () {
      expect(editCaption('سارة', null), isNull);
    });
  });

  group('what the editor saves', () {
    test('a cleared field is removed, kept items keep their quote, an added symptom has none', () {
      final c = editedSummary(
        chiefComplaint: (text: '  حكة في الأذن اليسرى ', quote: 'تحك أذنها'),
        duration: (text: '', quote: 'منذ ثلاثة أيام'),
        symptoms: [(text: 'هز الرأس', quote: 'تهز رأسها'), (text: 'رائحة من الأذن', quote: null), (text: ' ', quote: null)],
      )!;
      expect(c.toJson(), {
        'chief_complaint': {'value': 'حكة في الأذن اليسرى', 'quote': 'تحك أذنها'},
        'symptoms': [
          {'value': 'هز الرأس', 'quote': 'تهز رأسها'},
          {'value': 'رائحة من الأذن', 'quote': null},
        ],
      });
    });

    test('nothing left means nothing to save', () {
      expect(editedSummary(chiefComplaint: (text: '  ', quote: 'x')), isNull);
    });

    test('the JSON reads back to the same summary', () {
      final c = SummaryContent.fromJson(latest)!;
      final again = SummaryContent.fromJson(c.toJson())!;
      expect(again.chiefComplaint!.value, 'حكة في الأذن اليسرى');
      expect(again.symptoms.map((s) => s.quote), ['تهز رأسها', null]);
    });
  });

  testWidgets('the editor saves the changed text, an added symptom and the removal of a field', (tester) async {
    // A tall phone, so the whole editor is on screen.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SummaryContent? saved;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SummaryEditorScreen(
          caseId: 'c1',
          content: SummaryContent.fromJson(ai)!,
          onSave: (c) async => saved = c,
        ),
      ),
    ));
    expect(find.text('من كلام المالك: «تحك أذنها»'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'الشكوى الرئيسية'), 'حكة في الأذن اليسرى');
    await tester.enterText(find.widgetWithText(TextField, 'المدة'), '');
    await tester.tap(find.text('إضافة عرض'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'عرض 2'), 'رائحة من الأذن');
    await tester.tap(find.text('حفظ التعديل'));
    await tester.pumpAndSettle();

    expect(saved!.chiefComplaint!.value, 'حكة في الأذن اليسرى');
    expect(saved!.chiefComplaint!.quote, 'تحك أذنها');
    expect(saved!.duration, isNull);
    expect(saved!.symptoms.map((s) => s.value), ['هز الرأس', 'رائحة من الأذن']);
    expect(saved!.symptoms.last.quote, isNull);
  });
}
