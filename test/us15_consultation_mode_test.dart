import 'package:baytar/features/consultation/consultation_chat.dart';
import 'package:baytar/features/consultation/consultation_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-15 Change the Consultation Communication Mode.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  ConsultationMessage msg(String id, String sender, String body, int minute, {bool mode = false}) => ConsultationMessage.fromMap({
        'id': id,
        'sender_id': sender,
        'body': body,
        'kind': mode ? 'mode' : 'text',
        'created_at': '2026-11-12T10:${minute.toString().padLeft(2, '0')}:00Z',
      });

  group('the modes', () {
    test('video uses the camera and the microphone, voice only the microphone, text neither', () {
      expect(ConsultationMode.video.usesCamera, isTrue);
      expect(ConsultationMode.video.usesMicrophone, isTrue);
      expect(ConsultationMode.voice.usesCamera, isFalse);
      expect(ConsultationMode.voice.usesMicrophone, isTrue);
      expect(ConsultationMode.text.usesCamera, isFalse);
      expect(ConsultationMode.text.usesMicrophone, isFalse);
    });

    test('database values read back, and anything unknown is video', () {
      expect(ConsultationMode.parse('voice'), ConsultationMode.voice);
      expect(ConsultationMode.parse('text'), ConsultationMode.text);
      expect(ConsultationMode.parse(null), ConsultationMode.video);
      expect(ConsultationMode.parse('hologram'), ConsultationMode.video);
    });

    test("the veterinarian is told the owner's current mode", () {
      expect(ownerModeCaption(ConsultationMode.voice), 'المالك يتواصل بالصوت فقط');
      expect(ownerModeCaption(ConsultationMode.text), 'المالك يتواصل بالرسائل النصية');
    });
  });

  group('an unavailable mode', () {
    test('video without a camera explains that video is unavailable', () {
      final reason = modeUnavailableReason(ConsultationMode.video, hasCamera: false, hasMicrophone: true);
      expect(reason, startsWith('الفيديو غير متاح'));
    });

    test('voice without a microphone explains that voice is unavailable', () {
      final reason = modeUnavailableReason(ConsultationMode.voice, hasCamera: true, hasMicrophone: false);
      expect(reason, startsWith('الصوت غير متاح'));
    });

    test('text messages are always available', () {
      expect(modeUnavailableReason(ConsultationMode.text, hasCamera: false, hasMicrophone: false), isNull);
    });

    test('a mode the device supports has no message', () {
      expect(modeUnavailableReason(ConsultationMode.voice, hasCamera: false, hasMicrophone: true), isNull);
    });
  });

  group('the conversation', () {
    test("the owner's mode is the latest change, or the starting mode before any", () {
      final messages = [
        msg('1', 'owner', 'voice', 1, mode: true),
        msg('2', 'owner', 'الشبكة ضعيفة', 2),
        msg('3', 'owner', 'text', 3, mode: true),
      ];
      expect(currentMode(messages, ConsultationMode.video), ConsultationMode.text);
      expect(currentMode([msg('2', 'owner', 'مرحبا', 2)], ConsultationMode.voice), ConsultationMode.voice);
    });

    testWidgets('shows both sides, the mode change line, and sends a trimmed message', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ConsultationChat(
              messages: [
                msg('1', 'owner', 'text', 1, mode: true),
                msg('2', 'owner', 'لونا ما زالت تعطس', 2),
                msg('3', 'vet', 'هل تأكل جيداً؟', 3),
              ],
              myId: 'owner',
              otherLabel: 'الطبيب',
              onSend: (t) async {
                sent.add(t);
                return true;
              },
            ),
          ),
        ),
      ));
      expect(find.text('تحوّل المالك إلى: رسائل نصية'), findsOneWidget);
      expect(find.text('لونا ما زالت تعطس'), findsOneWidget);
      expect(find.text('هل تأكل جيداً؟'), findsOneWidget);
      expect(find.text('الطبيب'), findsOneWidget, reason: "only the other side's bubbles carry a name");

      await tester.enterText(find.byType(TextField), '  نعم تأكل  ');
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pump();
      expect(sent, ['نعم تأكل']);
      expect(find.text('  نعم تأكل  '), findsNothing, reason: 'the field clears once the message is sent');
    });

    testWidgets('a message that failed to send stays in the field', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConsultationChat(messages: const [], myId: 'vet', otherLabel: 'المالك', onSend: (_) async => false),
        ),
      ));
      expect(find.textContaining('لا توجد رسائل بعد'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'صف لي الأعراض');
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pump();
      expect(find.text('صف لي الأعراض'), findsOneWidget);
    });
  });
}
