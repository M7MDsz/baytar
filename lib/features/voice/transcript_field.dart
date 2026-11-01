import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';
import 'model/transcript_label.dart';
import 'transcript_repository.dart';
import 'transcript_state.dart';

const _idle = SavedTranscript(phase: TranscriptPhase.idle, label: TranscriptLabel.none, text: '');
const _loading = SavedTranscript(phase: TranscriptPhase.loading, label: TranscriptLabel.none, text: '');
const _failed = SavedTranscript(phase: TranscriptPhase.failed, label: TranscriptLabel.none, text: '');

/// US-36: the transcript of the draft's saved recording, and the owner's correction of it.
class TranscriptController extends ChangeNotifier {
  TranscriptController({TranscriptRepository? repository}) : _repo = repository ?? TranscriptRepository() {
    text.addListener(_notify);
  }

  final TranscriptRepository _repo;

  /// The transcript the owner reads and corrects.
  final text = TextEditingController();

  TranscriptPhase phase = TranscriptPhase.idle;
  TranscriptLabel label = TranscriptLabel.none;
  String _saved = '';

  /// Each request gets a number; a reply that arrives after a newer request (or a reset) is ignored.
  int _run = 0;
  bool _disposed = false;

  bool get hasCorrection => phase == TranscriptPhase.ready && hasUnsavedCorrection(saved: _saved, edited: text.text);

  /// The recording was replaced or deleted: forget the old transcript.
  void reset() {
    _run++;
    _show(_idle);
  }

  /// Shows what is stored on a draft that is opened again. A transcription still running is checked for 30 s.
  Future<void> load(String caseId) async {
    final run = ++_run;
    try {
      var saved = await _repo.fetch(caseId);
      for (var i = 0; i < 6 && saved.phase == TranscriptPhase.loading && run == _run; i++) {
        _show(saved);
        await Future<void>.delayed(const Duration(seconds: 5));
        saved = await _repo.fetch(caseId);
      }
      if (run == _run) _show(saved.phase == TranscriptPhase.loading ? _idle : saved);
    } catch (_) {
      if (run == _run) _show(_idle);
    }
  }

  /// Turns the draft's saved recording into text. Never throws: a failure shows the gentle note instead.
  Future<void> transcribe(String caseId) async {
    final run = ++_run;
    _show(_loading);
    SavedTranscript result;
    try {
      result = await _repo.transcribe(caseId);
    } on FunctionException catch (e) {
      result = switch (recoveryFor(transcribeErrorCode(e.details))) {
        TranscribeRecovery.reload => await _repo.fetch(caseId).catchError((Object _) => _failed),
        TranscribeRecovery.retry => _idle,
        TranscribeRecovery.failed => _failed,
      };
    } catch (_) {
      result = _failed;
    }
    if (run == _run) _show(result);
  }

  /// Saves the owner's correction, if there is one. Errors are left to the caller.
  Future<void> saveCorrection(String caseId) async {
    if (!hasCorrection) return;
    final run = ++_run;
    final saved = await _repo.saveCorrection(caseId, text.text);
    if (run == _run) _show(saved);
  }

  void _show(SavedTranscript s) {
    if (_disposed) return;
    phase = s.phase;
    label = s.label;
    _saved = s.text;
    if (text.text != s.text) text.text = s.text;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    text.dispose();
    super.dispose();
  }
}

/// US-36: shown under the voice recorder. A loading state while the recording is turned into text, then the
/// transcript with its label («نص تلقائي» / «عدّله المالك») for the owner to correct, or a gentle note on failure.
class TranscriptField extends StatelessWidget {
  const TranscriptField({
    super.key,
    required this.controller,
    required this.onTranscribe,
    required this.onSaveCorrection,
  });

  final TranscriptController controller;

  /// Saves the recording if needed, then asks for a transcript.
  final VoidCallback onTranscribe;
  final VoidCallback onSaveCorrection;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: KeyedSubtree(key: ValueKey(controller.phase), child: _body(context)),
          ),
        ),
      );

  Widget _body(BuildContext context) {
    final text = Theme.of(context).textTheme;
    switch (controller.phase) {
      case TranscriptPhase.loading:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Palette.juniperSoft, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('جارٍ تحويل الصوت إلى نص…', style: text.titleSmall!.copyWith(color: Palette.juniper)),
                const SizedBox(height: 2),
                Text('يجهز النص عادةً خلال 30 ثانية، ويمكنك متابعة تعبئة الحالة.', style: text.bodySmall),
              ]),
            ),
          ]),
        );
      case TranscriptPhase.ready:
        final byOwner = controller.label == TranscriptLabel.owner;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.notes_rounded, size: 20, color: Palette.juniper),
            const SizedBox(width: 8),
            Expanded(child: Text('نص التسجيل', style: text.titleSmall)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
              ),
              child: StatusPill(
                controller.label.text,
                key: ValueKey(controller.label),
                tone: byOwner ? Tone.accent : Tone.brand,
                icon: byOwner ? Icons.edit_rounded : Icons.auto_awesome_rounded,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: controller.text,
            minLines: 2,
            maxLines: 8,
            maxLength: 4000,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              helperText: 'راجع النص وصحّح ما يلزم قبل الإرسال. التسجيل الأصلي يبقى مرفقاً للطبيب.',
              helperMaxLines: 2,
            ),
          ),
          if (controller.hasCorrection)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onSaveCorrection,
                icon: const Icon(Icons.check_rounded),
                label: const Text('حفظ التصحيح'),
              ),
            ),
        ]);
      case TranscriptPhase.failed:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const NoticeBanner(
            'تعذّر تحويل التسجيل إلى نص هذه المرة. لا بأس، يمكنك إرسال الحالة وسيصل للطبيب التسجيل الصوتي فقط.',
            icon: Icons.info_outline_rounded,
            tone: Tone.neutral,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onTranscribe,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ]);
      case TranscriptPhase.idle:
        return OutlinedButton.icon(
          onPressed: onTranscribe,
          icon: const Icon(Icons.text_snippet_outlined),
          label: const Text('تحويل التسجيل إلى نص'),
        );
    }
  }
}
