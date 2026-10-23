import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/errors.dart';
import 'consultation_api.dart';

/// Video room for one appointment. Used by the owner (US-14) and by the veterinarian (US-19),
/// who passes a [panelBuilder] with the case details and an [onEnd] action.
class ConsultationRoomScreen extends StatefulWidget {
  const ConsultationRoomScreen({
    super.key,
    required this.appointmentId,
    this.panelBuilder,
    this.endLabel,
    this.onEnd,
  });

  final String appointmentId;
  final WidgetBuilder? panelBuilder;
  final String? endLabel;
  final Future<void> Function(BuildContext context)? onEnd;

  @override
  State<ConsultationRoomScreen> createState() => _ConsultationRoomScreenState();
}

class _ConsultationRoomScreenState extends State<ConsultationRoomScreen> {
  final _room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
  String? _error;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _room.addListener(_changed);
    _connect();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    try {
      final access = await fetchRoomAccess(widget.appointmentId);
      await _room.connect(access.url, access.token);
      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(true);
    } on JoinRefused catch (e) {
      _error = e.message;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _leave() async {
    await _room.disconnect();
    if (widget.onEnd != null && mounted) {
      await widget.onEnd!(context);
    } else if (mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _room.removeListener(_changed);
    _room.disconnect();
    _room.dispose();
    super.dispose();
  }

  VideoTrack? get _remoteVideo {
    for (final p in _room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) return pub.track;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الاستشارة')),
        body: Center(
          child: _connecting
              ? const Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جارٍ الاتصال...'),
                ])
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
        ),
      );
    }
    final local = _room.localParticipant;
    final localVideo = local?.videoTrackPublications.firstOrNull?.track;
    final remote = _remoteVideo;
    final micOn = local?.isMicrophoneEnabled() ?? false;
    final camOn = local?.isCameraEnabled() ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: remote != null
                ? VideoTrackRenderer(remote)
                : const Center(
                    child: Text('بانتظار انضمام الطرف الآخر...', style: TextStyle(color: Colors.white70)),
                  ),
          ),
          if (localVideo != null)
            PositionedDirectional(
              top: 16,
              end: 16,
              width: 110,
              height: 150,
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: VideoTrackRenderer(localVideo)),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _RoundButton(
                icon: micOn ? Icons.mic : Icons.mic_off,
                tooltip: micOn ? 'كتم الصوت' : 'تشغيل الصوت',
                onPressed: () => local?.setMicrophoneEnabled(!micOn),
              ),
              _RoundButton(
                icon: camOn ? Icons.videocam : Icons.videocam_off,
                tooltip: camOn ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
                onPressed: () => local?.setCameraEnabled(!camOn),
              ),
              if (widget.panelBuilder != null)
                _RoundButton(
                  icon: Icons.assignment_outlined,
                  tooltip: 'تفاصيل الحالة',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: widget.panelBuilder!,
                  ),
                ),
              _RoundButton(
                icon: Icons.call_end,
                tooltip: widget.endLabel ?? 'مغادرة',
                color: Colors.red,
                onPressed: _leave,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IconButton.filled(
          tooltip: tooltip,
          iconSize: 28,
          style: IconButton.styleFrom(backgroundColor: color ?? Colors.white24, padding: const EdgeInsets.all(14)),
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
      );
}
