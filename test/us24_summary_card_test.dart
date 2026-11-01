import 'package:baytar/features/case_summary/model/case_summary.dart';
import 'package:baytar/features/case_summary/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// US-24 Generate an AI-Structured Case Summary: what the veterinarian's summary card shows in every state.
void main() {
  const content = SummaryContent(
    chiefComplaint: SummaryItem(value: 'حك الأذن وهز الرأس', quote: 'تحك أذنها وتهز راسها'),
    onset: SummaryItem(value: 'بدأ فجأة', quote: 'فجأة'),
    affectedArea: SummaryItem(value: 'الأذن اليسرى', quote: 'أذنها اليسار'),
    symptoms: [SummaryItem(value: 'حكة', quote: 'تحك'), SummaryItem(value: 'هز الرأس', quote: 'تهز راسها')],
  );

  Future<void> pump(WidgetTester tester, SummaryContent? c, SummaryStatus s) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: SummaryCard(content: c, status: s))),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
  }

  test('rows follow reading order and leave out what the owner did not mention', () {
    final fields = summaryFields(content);
    expect(fields.map((f) => f.$1), ['الشكوى الرئيسية', 'البداية', 'المنطقة المصابة']);
    expect(fields.first.$2.value, 'حك الأذن وهز الرأس');
  });

  test('states without content say why, in the agreed words', () {
    expect(summaryStateMessage(SummaryStatus.pending, null), 'جارٍ إعداد الملخص…');
    expect(summaryStateMessage(SummaryStatus.notGenerated, null), 'تعذّر إنشاء ملخص: الوصف لا يذكر أعراضاً');
    expect(summaryStateMessage(SummaryStatus.failed, null), contains('تعذّر إنشاء الملخص'));
    expect(summaryStateMessage(SummaryStatus.none, null), contains('لا يوجد ملخص'));
    expect(summaryStateMessage(SummaryStatus.generated, content), isNull);
    expect(summaryStateMessage(SummaryStatus.generated, null), isNotNull);
  });

  test('a disregarded summary is never shown as accepted and shows no content', () {
    expect(summaryReviewPill(SummaryStatus.accepted)!.$1, 'مقبول');
    expect(summaryReviewPill(SummaryStatus.disregarded)!.$1, isNot('مقبول'));
    expect(summaryStateMessage(SummaryStatus.disregarded, content), contains('تجاهل'));
  });

  testWidgets('a generated summary is labelled advisory and not a diagnosis, with the owner\'s words', (tester) async {
    await pump(tester, content, SummaryStatus.generated);
    expect(find.text('ملخص بالذكاء الاصطناعي · استرشادي'), findsOneWidget);
    expect(find.text('ليس تشخيصاً'), findsOneWidget);
    expect(find.text('بانتظار مراجعتك'), findsOneWidget);
    expect(find.text('حك الأذن وهز الرأس'), findsOneWidget);
    expect(find.text('«تحك أذنها وتهز راسها»'), findsOneWidget);
    expect(find.text('هز الرأس'), findsOneWidget);
    expect(find.text('المدة'), findsNothing);
  });

  testWidgets('an accepted summary still says it is not a diagnosis', (tester) async {
    await pump(tester, content, SummaryStatus.accepted);
    expect(find.text('مقبول'), findsOneWidget);
    expect(find.text('ليس تشخيصاً'), findsOneWidget);
  });

  testWidgets('pending shows progress; disregarded hides the content even if some is passed', (tester) async {
    await pump(tester, null, SummaryStatus.pending);
    expect(find.text('جارٍ إعداد الملخص…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pump(tester, content, SummaryStatus.disregarded);
    expect(find.text('حك الأذن وهز الرأس'), findsNothing);
    expect(find.text('مقبول'), findsNothing);
    expect(find.text('تم تجاهله'), findsOneWidget);
  });
}
