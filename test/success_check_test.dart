import 'package:baytar/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AlertDialog forces its icon to the dialog's full width, which stretched the check to about 465 px wide and 72 px
  // tall. The painter draws from the width, so the disc spilled out of the dialog and covered the title.
  testWidgets('SuccessCheck stays a 72 px square inside an AlertDialog', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AlertDialog(icon: SuccessCheck(), title: Text('تم إرسال الحالة'), content: Text('رقم الحالة')),
      ),
    ));
    await tester.pumpAndSettle();

    final paint = find.descendant(of: find.byType(SuccessCheck), matching: find.byType(CustomPaint));
    expect(tester.getSize(paint), const Size.square(72));
    // Centred over the title, and it ends above it.
    expect(tester.getCenter(paint).dx, tester.getCenter(find.byType(AlertDialog)).dx);
    expect(tester.getBottomLeft(paint).dy, lessThanOrEqualTo(tester.getTopLeft(find.text('تم إرسال الحالة')).dy));
  });
}
