import 'package:baytar/features/animals/animal.dart';
import 'package:baytar/features/cases/animal_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const animals = [
    Animal(id: 'a', name: 'لونا', species: 'cat', sex: 'female'),
    Animal(id: 'b', name: 'غزالة الصحراء الذهبية الأصيلة', species: 'camel', sex: 'female'),
  ];

  Future<void> pump(WidgetTester tester, String? value) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            // The case form's list padding plus the card's.
            padding: const EdgeInsets.all(32),
            child: AnimalPicker(animals: animals, value: value, onChanged: (_) {}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // A long animal name made the dropdown as wide as that item, 18 px past the card on a 360 px phone.
  testWidgets('a long animal name fits a 360 px phone, closed and selected', (tester) async {
    await pump(tester, null);
    expect(tester.takeException(), isNull);
    await pump(tester, 'b');
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AnimalPicker)).width, lessThanOrEqualTo(360 - 64));
  });
}
