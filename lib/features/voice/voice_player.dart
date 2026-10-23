import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/storage.dart';
import 'voice_note.dart';

/// Play/pause control for a recorded or saved voice description.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.note, this.trailing});

  final VoiceNote note;
  final Widget? trailing;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.onPlayerStateChanged.listen((s) => setState(() => _state = s)))
      ..add(_player.onPositionChanged.listen((p) => setState(() => _position = p)))
      ..add(_player.onDurationChanged.listen((d) => setState(() => _duration = d)));
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) return _player.pause();
    if (_state == PlayerState.paused) return _player.resume();
    final note = widget.note;
    final source = note.localPath != null
        ? DeviceFileSource(note.localPath!)
        : UrlSource(await signedUrl(voiceBucket, note.remotePath!));
    await _player.play(source);
  }

  String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;
    return Row(children: [
      IconButton.filledTonal(
        tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
        onPressed: _toggle,
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
      const SizedBox(width: 8),
      Expanded(child: LinearProgressIndicator(value: progress.clamp(0, 1))),
      const SizedBox(width: 8),
      Text(_mmss(_duration == Duration.zero ? _position : _duration)),
      ?widget.trailing,
    ]);
  }
}
