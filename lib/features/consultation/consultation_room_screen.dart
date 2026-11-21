import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import 'consultation_api.dart';
import 'consultation_chat.dart';
import 'consultation_mode.dart';

/// Video room for one appointment. Used by the owner (US-14) and by the veterinarian (US-19),
/// who passes a [panelBuilder] with the case details and an [onEnd] action.
/// US-15: the owner can continue by voice only or by text messages without leaving the room; the veterinarian sees the
/// owner's current mode and answers in the same messages.
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
  final bool _isVet = Session.instance.profile?.role == UserRole.vet;
  String? _error;
  bool _connecting = true;

  /// US-15: the owner's mode, on both sides. Every consultation starts in video.
  ConsultationMode _mode = ConsultationMode.video;
  bool _switching = false;
  List<ConsultationMessage> _messages = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _messageStream;
  bool _chatOpen = false;

  /// Text messages already seen, for the unread badge on the messages button.
  int _seenText = 0;

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
    // An owner who comes back keeps the mode they chose; a new consultation starts in video.
    await _loadMode();
    _listenToMessages();
    await _applyDevices(_mode, quiet: false);
  }

  Future<void> _loadMode() async {
    try {
      final row = await db.from('appointments').select('owner_mode').eq('id', widget.appointmentId).maybeSingle();
      final mode = ConsultationMode.parse(row?['owner_mode']);
      if (mounted) {
        setState(() {
          _mode = mode;
          _chatOpen = mode == ConsultationMode.text;
        });
      }
    } catch (_) {
      // Without it the room starts in video, as before US-15.
    }
  }

  void _listenToMessages() {
    _messageStream = db
        .from('consultation_messages')
        .stream(primaryKey: ['id'])
        .eq('appointment_id', widget.appointmentId)
        .order('created_at')
        .listen((rows) {
      if (!mounted) return;
      final messages = rows.map(ConsultationMessage.fromMap).toList();
      final mode = currentMode(messages, _mode);
      final changed = mode != _mode;
      setState(() {
        _messages = messages;
        if (_chatOpen) _seenText = _textCount(messages);
        if (changed && _isVet) {
          _mode = mode;
          // The owner can no longer talk: open the messages so the veterinarian can answer in writing.
          if (mode == ConsultationMode.text) _chatOpen = true;
        }
      });
      if (changed && _isVet) showSnack(context, ownerModeCaption(mode));
    }, onError: (_) {});
  }

  /// Turns the microphone and camera on or off for [mode]. Best effort, as before US-15: a refused permission keeps
  /// the call open with that device off. Returns false when a device that the mode needs could not be turned on.
  Future<bool> _applyDevices(ConsultationMode mode, {bool quiet = true}) async {
    final local = _room.localParticipant;
    if (local == null) return false;
    // The veterinarian's own camera and microphone do not follow the owner's mode.
    final camera = _isVet || mode.usesCamera;
    final microphone = _isVet || mode.usesMicrophone;
    var ok = true;
    try {
      if (!camera) await local.setCameraEnabled(false);
      await local.setMicrophoneEnabled(microphone);
      if (camera) await local.setCameraEnabled(true);
    } catch (_) {
      ok = false;
      if (!quiet && mounted) {
        showSnack(context, 'تعذّر تشغيل الكاميرا أو الميكروفون. اسمح لبيطار باستخدامهما ثم أعد المحاولة من الأزرار.',
            error: true);
      }
    }
    return ok;
  }

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

  /// US-15: whether this device has what [mode] needs. When the devices cannot be listed, trying decides.
  Future<String?> _unavailableReason(ConsultationMode mode) async {
    if (mode == ConsultationMode.text) return null;
    var hasCamera = true, hasMicrophone = true;
    try {
      final devices = await Hardware.instance.enumerateDevices();
      hasCamera = devices.any((d) => d.kind == 'videoinput');
      hasMicrophone = devices.any((d) => d.kind == 'audioinput');
    } catch (_) {}
    return modeUnavailableReason(mode, hasCamera: hasCamera, hasMicrophone: hasMicrophone);
  }

  /// US-15: the owner switches mode. The room stays connected throughout; only the devices change.
  Future<void> _changeMode() async {
    final next = await pickConsultationMode(context, _mode);
    if (next == null || next == _mode || !mounted) return;
    final reason = await _unavailableReason(next);
    if (!mounted) return;
    if (reason != null) {
      showSnack(context, reason, error: true);
      return;
    }
    setState(() => _switching = true);
    final previous = _mode;
    if (!await _applyDevices(next)) {
      await _applyDevices(previous);
      if (mounted) {
        // Video needs the camera, voice the microphone: say which one is missing.
        final reason = modeUnavailableReason(next, hasCamera: !next.usesCamera, hasMicrophone: next.usesCamera);
        showSnack(context, reason ?? 'تعذّر تغيير طريقة التواصل الآن.', error: true);
        setState(() => _switching = false);
      }
      return;
    }
    try {
      await db.rpc('set_consultation_mode', params: {'p_appointment': widget.appointmentId, 'p_mode': next.name});
      if (!mounted) return;
      setState(() {
        _mode = next;
        _chatOpen = next == ConsultationMode.text;
        _seenText = _textCount(_messages);
      });
      showSnack(context, 'تكمل الاستشارة الآن: ${next.label}');
    } catch (e) {
      await _applyDevices(previous);
      if (mounted) showSnack(context, friendlyError(e, consultationChatErrors), error: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<bool> _send(String text) async {
    try {
      await db.rpc('send_consultation_message', params: {'p_appointment': widget.appointmentId, 'p_body': text});
      return true;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, consultationChatErrors), error: true);
      return false;
    }
  }

  void _toggleChat() => setState(() {
        _chatOpen = !_chatOpen;
        _seenText = _textCount(_messages);
      });

  static int _textCount(List<ConsultationMessage> messages) => messages.where((m) => !m.isModeChange).length;

  Future<void> _leave() async {
    // The vet's End asks first and may stay in the call; leaving the page disconnects in dispose().
    if (widget.onEnd != null) {
      await widget.onEnd!(context);
      return;
    }
    await _room.disconnect();
    if (!mounted) return;
    // Opened from a link there is nothing to pop.
    context.leave('/appointments');
  }

  @override
  void dispose() {
    _messageStream?.cancel();
    _room.removeListener(_changed);
    // Dispose only once the disconnect has finished. Disposing straight away let LiveKit deliver the other side
    // leaving into a disposed room, which threw in the background after the vet had moved on to the outcome form.
    _room.disconnect().whenComplete(_room.dispose);
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
    // In voice and text mode the owner's screen draws no video at all, so none is received (adaptive stream).
    final showVideo = _isVet || _mode == ConsultationMode.video;
    final localVideo = showVideo ? local?.videoTrackPublications.firstOrNull?.track : null;
    final remote = showVideo ? _remoteVideo : null;
    final micOn = local?.isMicrophoneEnabled() ?? false;
    final camOn = local?.isCameraEnabled() ?? false;
    final unread = _chatOpen ? 0 : (_textCount(_messages) - _seenText).clamp(0, 99);
    return Scaffold(
      backgroundColor: const Color(0xFF07130F),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: !_chatOpen,
        child: Column(children: [
          Expanded(
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
                          child: SingleChildScrollView(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              _otherParty(radius: _chatOpen ? 36 : 56),
                              const SizedBox(height: 14),
                              Text(
                                _stageCaption,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ]),
                          ),
                        ),
                      ),
              ),
              PositionedDirectional(
                top: 14,
                start: 14,
                child: _ModeChip(
                  label: _isVet ? ownerModeCaption(_mode) : 'طريقتك: ${_mode.label}',
                  icon: _mode.icon,
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
                    // Cover, not the default contain: a landscape camera in this portrait tile left black bands.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: VideoTrackRenderer(localVideo, fit: VideoViewFit.cover),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _chatOpen ? 12 : 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_isVet || _mode.usesMicrophone)
                          _RoundButton(
                            icon: micOn ? Icons.mic : Icons.mic_off,
                            tooltip: micOn ? 'كتم الصوت' : 'تشغيل الصوت',
                            onPressed: () => _setDevice(() async => local?.setMicrophoneEnabled(!micOn)),
                          ),
                        if (_isVet || _mode.usesCamera)
                          _RoundButton(
                            icon: camOn ? Icons.videocam : Icons.videocam_off,
                            tooltip: camOn ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
                            onPressed: () => _setDevice(() async => local?.setCameraEnabled(!camOn)),
                          ),
                        if (!_isVet)
                          _RoundButton(
                            icon: Icons.swap_horiz_rounded,
                            tooltip: 'تغيير طريقة التواصل',
                            busy: _switching,
                            onPressed: _switching ? null : _changeMode,
                          ),
                        if (_isVet || _mode != ConsultationMode.text)
                          _RoundButton(
                            icon: _chatOpen ? Icons.speaker_notes_off_outlined : Icons.chat_bubble_outline_rounded,
                            tooltip: _chatOpen ? 'إخفاء الرسائل' : 'الرسائل',
                            badge: unread,
                            onPressed: _toggleChat,
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
              ),
            ]),
          ),
          if (_chatOpen)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * (MediaQuery.viewInsetsOf(context).bottom > 0 ? 0.42 : 0.55),
              child: ConsultationChat(
                messages: _messages,
                myId: currentUserId,
                otherLabel: _isVet ? 'المالك' : 'الطبيب',
                onSend: _send,
              ),
            ),
        ]),
      ),
    );
  }

  /// What the dark stage says when there is no video to show.
  String get _stageCaption {
    if (_room.remoteParticipants.isEmpty) return 'بانتظار انضمام الطرف الآخر...';
    if (!_isVet) {
      return switch (_mode) {
        ConsultationMode.voice => 'مكالمة صوتية مع الطبيب',
        ConsultationMode.text => 'متصل بالطبيب · تكملان بالرسائل',
        ConsultationMode.video => 'الطبيب متصل، والكاميرا لديه مطفأة',
      };
    }
    return _mode == ConsultationMode.video ? 'المالك متصل، والكاميرا لديه مطفأة' : ownerModeCaption(_mode);
  }

  /// Who the user is waiting for: the veterinarian for an owner, the animal for a veterinarian.
  Widget _otherParty({required double radius}) =>
      _isVet ? SpeciesAvatar(null, radius: radius) : DoctorAvatar(null, radius: radius);
}

/// US-15: the owner's current mode, in the top corner of the room.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.badge = 0,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final int badge;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text(arabicDigits(badge)),
          backgroundColor: Palette.alert,
          child: IconButton.filled(
            tooltip: tooltip,
            iconSize: 26,
            style: IconButton.styleFrom(
              backgroundColor: color ?? Colors.white.withValues(alpha: 0.16),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
              padding: const EdgeInsets.all(14),
            ),
            onPressed: onPressed,
            icon: busy
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                : Icon(icon, color: Colors.white),
          ),
        ),
      );
}
