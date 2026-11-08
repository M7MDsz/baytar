import 'package:baytar/features/booking/booking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The case options put a RadioListTile straight on a coloured box, which hid its tap ripple; Flutter asserts
  // "ListTile background color or ink splashes may be invisible".
  testWidgets('a case option on the booking screen keeps its ripple visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RadioGroup<String>(
          groupValue: 'a',
          onChanged: (_) {},
          child: const Column(children: [
            BookingChoice(selected: true, child: RadioListTile<String>(value: 'a', title: Text('لونا'))),
            BookingChoice(selected: false, child: RadioListTile<String>(value: 'b', title: Text('غزالة'))),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
