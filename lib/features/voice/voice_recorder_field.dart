import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/widgets.dart';
import 'voice_note.dart';
import 'voice_player.dart';

/// US-04: record, play back, delete and re-record a voice description.
class VoiceRecorderField extends StatefulWidget {
  const VoiceRecorderField({super.key, required this.value, required this.onChanged});

  final VoiceNote? value;
  final ValueChanged<VoiceNote?> onChanged;

  @override
  State<VoiceRecorderField> createState() => _VoiceRecorderFieldState();
}

class _VoiceRecorderFieldState extends State<VoiceRecorderField> {
  static const maxLength = Duration(minutes: 5);

  final _recorder = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        showSnack(context, 'الميكروفون غير متاح. اسمح لبيطار باستخدام الميكروفون من إعدادات الجهاز.', error: true);
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    } catch (_) {
      if (mounted) showSnack(context, 'الميكروفون غير متاح على هذا الجهاز.', error: true);
      return;
    }
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= maxLength) _stop();
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path != null) widget.onChanged(VoiceNote.local(path));
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف التسجيل',
      message: 'هل تريد حذف التسجيل الصوتي؟ يمكنك تسجيل بديل بعد الحذف.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (ok) widget.onChanged(null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.value;
    if (_recording) {
      return Row(children: [
        const Icon(Icons.fiber_manual_record, color: Colors.red),
        const SizedBox(width: 8),
        Text('جارٍ التسجيل ${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}'),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('إيقاف'),
        ),
      ]);
    }
    if (note == null) {
      return OutlinedButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.mic_none),
        label: const Text('تسجيل وصف صوتي'),
      );
    }
    return VoicePlayer(
      key: ValueKey(note.localPath ?? note.remotePath),
      note: note,
      trailing: IconButton(tooltip: 'حذف التسجيل', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
    );
  }
}
