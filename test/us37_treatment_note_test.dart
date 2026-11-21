import 'package:baytar/features/treatment_notes/treatment_note.dart';
import 'package:baytar/features/treatment_notes/treatment_note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-37 Issue a Treatment Note.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  const amoxicillin = Medicine(name: 'Amoxicillin', dose: '50 mg', frequency: 'مرتين يومياً', duration: '7 أيام');

  group('what can be issued', () {
    test('a medicine missing its name, dose, frequency or duration cannot be issued', () {
      const missingDose = Medicine(name: 'Amoxicillin', dose: ' ', frequency: 'مرتين يومياً', duration: '');
      expect(missingDose.missing, ['الجرعة', 'المدة']);
      expect(noteProblem('راحة', [missingDose]), 'أكمل الدواء 1: الجرعة، المدة.');
    });

    test('neither care instructions nor a medicine: issuing is prevented', () {
      expect(noteProblem('   ', const []), 'اكتب تعليمات العناية أو أضف دواءً واحداً على الأقل.');
    });

    test('instructions alone, a medicine alone, or both can be issued', () {
      expect(noteProblem('راحة وماء نظيف', const []), isNull);
      expect(noteProblem('', const [amoxicillin]), isNull);
      expect(noteProblem('راحة', const [amoxicillin]), isNull);
    });

    test('the medicines go to the server trimmed, field by field', () {
      const m = Medicine(name: ' Meloxicam ', dose: '0.1 mg/kg ', frequency: ' مرة يومياً', duration: '3 أيام');
      expect(m.toJson(), {'name': 'Meloxicam', 'dose': '0.1 mg/kg', 'frequency': 'مرة يومياً', 'duration': '3 أيام'});
    });
  });

  group('an issued note', () {
    final first = TreatmentNote.fromMap({
      'id': 'n1',
      'appointment_id': 'a1',
      'vet_name': 'سارة القحطاني',
      'license_number': 'L-100',
      'care_instructions': 'قطرة للأذن وراحة',
      'corrects_note_id': null,
      'issued_at': '2026-11-12T18:40:00Z',
      'medicines': [
        {'name': 'Amoxicillin', 'dose': '50 mg', 'frequency': 'مرتين يومياً', 'duration': '7 أيام'},
      ],
    });
    final correction = TreatmentNote.fromMap({
      'id': 'n2',
      'appointment_id': 'a1',
      'vet_name': 'سارة القحطاني',
      'license_number': 'L-100',
      'care_instructions': 'قطرة للأذن مرتين يومياً',
      'corrects_note_id': 'n1',
      'issued_at': '2026-11-12T19:05:00Z',
      'medicines': [],
    });

    test('a correction marks the note it corrects, and both remain', () {
      expect(correctedNoteIds([first, correction]), {'n1'});
      expect(first.medicines.single.name, 'Amoxicillin');
    });

    testWidgets("shows the vet's name, license number and date, and is final", (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: TreatmentNoteCard(note: first))),
        ),
      ));
      expect(find.text('د. سارة القحطاني · ترخيص رقم L-100'), findsOneWidget);
      expect(find.textContaining('صدرت '), findsOneWidget);
      expect(find.text('نهائية، لا تُعدّل'), findsOneWidget);
      expect(find.text('قطرة للأذن وراحة'), findsOneWidget);
      expect(find.text('50 mg · مرتين يومياً · لمدة 7 أيام'), findsOneWidget);
      expect(find.text('إصدار تصحيح'), findsNothing, reason: 'the owner has no correction action');
      expect(find.byType(TextField), findsNothing, reason: 'nothing on an issued note can be edited');
    });

    testWidgets('a replaced note says a correction was issued; the vet corrects only the latest', (tester) async {
      var corrected = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              TreatmentNoteCard(note: first, replaced: true, onCorrect: () => corrected++),
              TreatmentNoteCard(note: correction, onCorrect: () => corrected++),
            ]),
          ),
        ),
      ));
      expect(find.text('صدر تصحيح لها'), findsOneWidget);
      expect(find.text('ملاحظة علاج (تصحيح)'), findsOneWidget);
      expect(find.text('إصدار تصحيح'), findsOneWidget);
      await tester.tap(find.text('إصدار تصحيح'));
      expect(corrected, 1);
    });
  });

  test('the doctor title is not repeated', () {
    expect(vetTitle('سارة القحطاني'), 'د. سارة القحطاني');
    expect(vetTitle('د. خالد الشهري'), 'د. خالد الشهري');
  });
}
