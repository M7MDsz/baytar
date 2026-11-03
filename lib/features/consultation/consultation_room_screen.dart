import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
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
    } on JoinRefused catch (e) {
      _error = e.message;
    } catch (e) {
      _error = friendlyError(e);
      // A connection that failed half way must not stay in the room behind the error screen.
      await _room.disconnect();
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
    if (_error != null) return;
    await _setDevice(() async => _room.localParticipant?.setMicrophoneEnabled(true));
    await _setDevice(() async => _room.localParticipant?.setCameraEnabled(true));
  }

  /// Microphone and camera are best effort: a refused permission keeps the call open with that device off,
  /// and the user can try again from the controls.
  Future<void> _setDevice(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showSnack(context, 'تعذّر تشغيل الكاميرا أو الميكروفون. اسمح لبيطار باستخدامهما ثم أعد المحاولة من الأزرار.',
            error: true);
      }
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
        body: _connecting
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _otherParty(radius: 48),
                  const SizedBox(height: 20),
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 12),
                  Text('جارٍ الاتصال...', style: Theme.of(context).textTheme.titleMedium),
                ]),
              )
            : EmptyState(icon: Icons.videocam_off_outlined, message: _error!),
      );
    }
    final local = _room.localParticipant;
    final localVideo = local?.videoTrackPublications.firstOrNull?.track;
    final remote = _remoteVideo;
    final micOn = local?.isMicrophoneEnabled() ?? false;
    final camOn = local?.isCameraEnabled() ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFF07130F),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: remote != null
                ? VideoTrackRenderer(remote)
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Palette.juniperMid, Palette.juniper, Color(0xFF07130F)],
                      ),
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _otherParty(radius: 56),
                        const SizedBox(height: 18),
                        const Text(
                          'بانتظار انضمام الطرف الآخر...',
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ),
          ),
          if (localVideo != null)
            PositionedDirectional(
              top: 16,
              end: 16,
              width: 110,
              height: 150,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(15), child: VideoTrackRenderer(localVideo)),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
              _RoundButton(
                icon: micOn ? Icons.mic : Icons.mic_off,
                tooltip: micOn ? 'كتم الصوت' : 'تشغيل الصوت',
                onPressed: () => _setDevice(() async => local?.setMicrophoneEnabled(!micOn)),
              ),
              _RoundButton(
                icon: camOn ? Icons.videocam : Icons.videocam_off,
                tooltip: camOn ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
                onPressed: () => _setDevice(() async => local?.setCameraEnabled(!camOn)),
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
                color: Palette.danger,
                onPressed: _leave,
              ),
              ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Who the user is waiting for: the veterinarian for an owner, the animal for a veterinarian.
  Widget _otherParty({required double radius}) => Session.instance.profile?.role == UserRole.vet
      ? SpeciesAvatar(null, radius: radius)
      : DoctorAvatar(null, radius: radius);
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: IconButton.filled(
          tooltip: tooltip,
          iconSize: 26,
          style: IconButton.styleFrom(
            backgroundColor: color ?? Colors.white.withValues(alpha: 0.16),
            padding: const EdgeInsets.all(14),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
      );
}
