import 'package:flutter/material.dart';

import '../../core/formatting.dart';

/// US-15: how the owner takes part in a consultation. The names are the database values (`owner_mode`).
enum ConsultationMode {
  video('فيديو', 'صورة وصوت', Icons.videocam_rounded),
  voice('صوت فقط', 'تُطفأ الكاميرا ويستمر الصوت', Icons.mic_rounded),
  text('رسائل نصية', 'يُطفأ الصوت والكاميرا وتكملان بالكتابة', Icons.chat_bubble_outline_rounded);

  const ConsultationMode(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;

  /// Reads the database value; anything unknown is video, the mode every consultation starts in.
  static ConsultationMode parse(Object? raw) => values.firstWhere((m) => m.name == raw, orElse: () => video);

  bool get usesCamera => this == video;
  bool get usesMicrophone => this != text;
}

/// The longest message the server accepts.
const maxConsultationMessage = 1000;

/// What the veterinarian sees about the owner's current mode.
String ownerModeCaption(ConsultationMode mode) => switch (mode) {
      ConsultationMode.video => 'المالك يتواصل بالفيديو',
      ConsultationMode.voice => 'المالك يتواصل بالصوت فقط',
      ConsultationMode.text => 'المالك يتواصل بالرسائل النصية',
    };

/// The line the conversation shows when the owner changes mode.
String modeChangeLine(ConsultationMode mode) => 'تحوّل المالك إلى: ${mode.label}';

/// Why [mode] cannot be used on this device right now, or null when it can. Text messages always work.
String? modeUnavailableReason(ConsultationMode mode, {required bool hasCamera, required bool hasMicrophone}) {
  if (mode.usesCamera && !hasCamera) {
    return 'الفيديو غير متاح: لا توجد كاميرا على هذا الجهاز أو لم يُسمح لبيطار باستخدامها. جرّب الصوت فقط أو الرسائل النصية.';
  }
  if (mode.usesMicrophone && !hasMicrophone) {
    return 'الصوت غير متاح: لا يوجد ميكروفون أو لم يُسمح لبيطار باستخدامه. يمكنك المتابعة بالرسائل النصية.';
  }
  return null;
}

/// The codes `set_consultation_mode` and `send_consultation_message` raise, in the app's words.
const consultationChatErrors = {
  'not_in_consultation': 'الاستشارة غير جارية الآن.',
  'empty_message': 'اكتب رسالتك أولاً.',
  'message_too_long': 'الرسالة طويلة، الحد ١٠٠٠ حرف.',
  'owner_only': 'تغيير طريقة التواصل للمالك فقط.',
  'bad_mode': 'طريقة التواصل غير معروفة.',
};

/// One row of `consultation_messages`: a text message, or the owner's change of mode.
class ConsultationMessage {
  const ConsultationMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.isModeChange = false,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isModeChange;

  /// The new mode, for a mode change.
  ConsultationMode? get mode => isModeChange ? ConsultationMode.parse(body) : null;

  factory ConsultationMessage.fromMap(Map<String, dynamic> m) => ConsultationMessage(
        id: m['id'] as String,
        senderId: m['sender_id'] as String,
        body: m['body'] as String,
        createdAt: parseTs(m['created_at']),
        isModeChange: m['kind'] == 'mode',
      );
}

/// The owner's mode as the conversation tells it: the latest change, or [initial] before any.
ConsultationMode currentMode(Iterable<ConsultationMessage> messages, ConsultationMode initial) {
  ConsultationMode? latest;
  DateTime? at;
  for (final m in messages) {
    if (m.isModeChange && (at == null || !m.createdAt.isBefore(at))) {
      latest = m.mode;
      at = m.createdAt;
    }
  }
  return latest ?? initial;
}
