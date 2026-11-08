import 'package:baytar/features/outcome_editor/outcome_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// QA M-4: when the saved outcome cannot be read, the veterinarian gets an error with retry, never an empty
// form that could be saved over the existing draft.
void main() {
  testWidgets('a failed read shows retry and no editable form', (tester) async {
    // No backend is set up in tests, so reading the outcome throws, as it does offline.
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: OutcomeFormScreen(appointmentId: 'a1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('اعتماد النتيجة'), findsNothing);
    expect(find.text('حفظ كمسودة'), findsNothing);
  });
}
