import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import 'consultation_mode.dart';

/// US-15: the consultation's text messages, with the owner's mode changes as small centred lines. Pure display: the
/// room screen owns the message stream and sends through [onSend], which returns false when sending failed (the text
/// then stays in the field).
class ConsultationChat extends StatefulWidget {
  const ConsultationChat({
    super.key,
    required this.messages,
    required this.myId,
    required this.otherLabel,
    required this.onSend,
  });

  final List<ConsultationMessage> messages;
  final String? myId;

  /// Who the other side is, for their bubbles: «الطبيب» or «المالك».
  final String otherLabel;
  final Future<bool> Function(String text) onSend;

  @override
  State<ConsultationChat> createState() => _ConsultationChatState();
}

class _ConsultationChatState extends State<ConsultationChat> {
  final _field = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await widget.onSend(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) _field.clear();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final messages = widget.messages.reversed.toList();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Palette.juniper),
            const SizedBox(width: 8),
            Text('الرسائل', style: text.titleSmall),
            const Spacer(),
            Text('الاستشارة ما زالت متصلة', style: text.bodySmall),
          ]),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا توجد رسائل بعد. اكتب رسالتك وسيقرؤها ${widget.otherLabel} فوراً.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium!.copyWith(color: Palette.muted),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    if (m.isModeChange) return _ModeLine(mode: m.mode!);
                    return _Bubble(message: m, mine: m.senderId == widget.myId, otherLabel: widget.otherLabel);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: maxConsultationMessage,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'اكتب رسالة…', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.otherLabel});

  final ConsultationMessage message;
  final bool mine;
  final String otherLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      // Like other chat apps in Arabic: your own messages on the left (the end of a right-to-left line).
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? Palette.juniper : Palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: Palette.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine) Text(otherLabel, style: text.labelSmall!.copyWith(color: Palette.accentDeep)),
            Text(message.body, style: text.bodyMedium!.copyWith(color: mine ? Colors.white : Palette.ink)),
            const SizedBox(height: 2),
            Text(
              formatTime(message.createdAt),
              style: text.labelSmall!.copyWith(color: mine ? Colors.white70 : Palette.muted),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ModeLine extends StatelessWidget {
  const _ModeLine({required this.mode});

  final ConsultationMode mode;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Palette.surfaceMuted, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(mode.icon, size: 15, color: Palette.muted),
            const SizedBox(width: 6),
            Text(modeChangeLine(mode), style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Palette.body)),
          ]),
        ),
      );
}

/// The owner picks how to continue. Returns the chosen mode, or null when dismissed.
Future<ConsultationMode?> pickConsultationMode(BuildContext context, ConsultationMode current) =>
    showModalBottomSheet<ConsultationMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('طريقة التواصل', textAlign: TextAlign.center, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'غيّرها إذا ضعف الاتصال. تبقى الاستشارة متصلة ويرى الطبيب اختيارك.',
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: Palette.muted),
              ),
              const SizedBox(height: 12),
              for (final m in ConsultationMode.values)
                ListTile(
                  leading: Icon(m.icon, color: m == current ? Palette.accent : Palette.juniper),
                  title: Text(m.label),
                  subtitle: Text(m.hint),
                  trailing: m == current ? const Icon(Icons.check_circle_rounded, color: Palette.accent) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
                  selected: m == current,
                  onTap: () => Navigator.pop(context, m),
                ),
            ]),
          ),
        );
      },
    );
