import 'package:baytar/app/theme.dart';
import 'package:baytar/features/case_summary/summary_review_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, double width) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SummaryDecisionButtons(busy: false, onAccept: () {}, onDisregard: () {}),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double lines(WidgetTester tester, String label) {
    final size = tester.getSize(find.text(label));
    final style = tester.widget<DefaultTextStyle>(
      find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first,
    );
    return size.height / ((style.style.fontSize ?? 14) * (style.style.height ?? 1.2));
  }

  // On a 360 px phone the panel is about 296 px wide: side by side the labels wrapped onto two lines.
  testWidgets('a 296 px panel stacks Accept above Disregard, each label on one line', (tester) async {
    await pumpAt(tester, 296);
    final accept = tester.getCenter(find.text('قبول الملخص'));
    final disregard = tester.getCenter(find.text('تجاهل الملخص'));
    expect(accept.dy, lessThan(disregard.dy));
    expect(lines(tester, 'قبول الملخص'), lessThan(1.5));
    expect(lines(tester, 'تجاهل الملخص'), lessThan(1.5));
  });

  testWidgets('a wider panel keeps them side by side', (tester) async {
    await pumpAt(tester, 330);
    expect(tester.getCenter(find.text('قبول الملخص')).dy, tester.getCenter(find.text('تجاهل الملخص')).dy);
  });
}
