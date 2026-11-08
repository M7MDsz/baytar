import 'package:baytar/core/formatting.dart';
import 'package:baytar/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // On a 360 px phone «admin.demo@example.com» did not fit beside its label and broke as «…example.co» / «m».
  testWidgets('a long email wraps after the @, not mid-word', (tester) async {
    const email = 'admin.demo@example.com';
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SizedBox(width: 300, child: InfoRow('البريد', wrappableEmail(email)))),
      ),
    ));
    final shown = wrappableEmail(email);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(shown));
    final painter = TextPainter(text: paragraph.text, textDirection: paragraph.textDirection)
      ..layout(maxWidth: paragraph.size.width);
    final lastLine = painter.getLineBoundary(TextPosition(offset: shown.length - 1));
    expect(painter.computeLineMetrics().length, 2, reason: 'the test needs the email not to fit on one line');
    expect(shown.substring(lastLine.start), 'example.com');
  });

  test('only the first @ gets the break opportunity', () {
    expect(wrappableEmail('a@b.c'), 'a@​b.c');
  });
}
