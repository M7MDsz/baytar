import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';
import '../voice/model/transcript_label.dart';
import '../voice/voice_note.dart';
import '../voice/voice_player.dart';
import 'model/case_summary.dart';
import 'summary_review.dart';
import 'summary_review_repository.dart';

/// Draws the AI summary itself (the screen that uses the panel passes the summary card).
typedef SummaryBuilder = Widget Function(SummaryContent? content, SummaryStatus status);

/// US-25 Compare, US-27 Accept, US-28 Disregard: on the veterinarian's case, the owner's original description
/// (with the recording and its labelled transcript) stays on top and is never hidden or replaced; the AI summary sits
/// under it, with Accept and Disregard (each confirmed in a bottom sheet) and then who decided and when.
class SummaryReviewPanel extends StatefulWidget {
  const SummaryReviewPanel({
    super.key,
    required this.caseId,
    required this.summaryBuilder,
    this.description,
    this.voicePath,
  });

  final String caseId;
  final SummaryBuilder summaryBuilder;

  /// The description and recording the screen already has, shown until the comparison loads (and if it cannot).
  final String? description;
  final String? voicePath;

  @override
  State<SummaryReviewPanel> createState() => _SummaryReviewPanelState();
}

class _SummaryReviewPanelState extends State<SummaryReviewPanel> {
  final _repo = SummaryReviewRepository();
  VetCaseSummary? _data;
  Object? _error;
  bool _busy = false;
  Timer? _poll;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// A summary is usually ready seconds after the case is sent: while pending, look again every 5 s for a minute.
  Future<void> _load() async {
    _poll?.cancel();
    try {
      final data = await _repo.load(widget.caseId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
      if (data.status == SummaryStatus.pending && _polls++ < 12) {
        _poll = Timer(const Duration(seconds: 5), _load);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _review(ReviewAction action) async {
    final accept = action == ReviewAction.accept;
    final confirmed = await confirmDialog(
      context,
      title: accept ? 'قبول الملخص؟' : 'تجاهل الملخص؟',
      message: accept
          ? 'سيُسجَّل أنك راجعت الملخص ووجدته مطابقاً لوصف المالك. يبقى الملخص استرشادياً وليس تشخيصاً، ولا يمكن تغيير القرار بعد ذلك.'
          : 'لن يُعرض الملخص بعد ذلك، ويبقى وصف المالك الأصلي كما هو. لا يمكن تغيير القرار بعد ذلك.',
      confirmLabel: accept ? 'قبول الملخص' : 'تجاهل الملخص',
      destructive: !accept,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.review(widget.caseId, action);
      if (mounted) showSnack(context, accept ? 'تم قبول الملخص.' : 'تم تجاهل الملخص.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, summaryReviewErrors), error: true);
    } finally {
      // After a decision, or if someone already decided, show what is stored.
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    const motion = Duration(milliseconds: 300);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('وصف المالك الأصلي'),
      _OriginalCard(
        description: d?.description ?? widget.description,
        voicePath: d?.voicePath ?? widget.voicePath,
        transcript: d?.transcript,
        label: d?.transcriptLabel ?? TranscriptLabel.none,
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: motion,
        child: KeyedSubtree(
          key: ValueKey(d != null ? 'data' : (_error != null ? 'error' : 'loading')),
          child: d != null
              ? widget.summaryBuilder(d.content, d.status)
              : _error != null
                  ? _LoadError(message: friendlyError(_error!, summaryReviewErrors), onRetry: _load)
                  : const _Loading(),
        ),
      ),
      AnimatedSize(
        duration: motion,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion,
          child: KeyedSubtree(key: ValueKey(d?.status), child: _decision(context, d)),
        ),
      ),
    ]);
  }

  Widget _decision(BuildContext context, VetCaseSummary? d) {
    if (d == null) return const SizedBox(width: double.infinity);
    final caption = reviewCaption(d.status, d.reviewerName, d.reviewedAt);
    if (caption != null) return _DecisionBanner(accepted: d.status == SummaryStatus.accepted, caption: caption);
    if (!d.status.awaitingReview) return const SizedBox(width: double.infinity);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SummaryDecisionButtons(
          busy: _busy,
          onAccept: () => _review(ReviewAction.accept),
          onDisregard: () => _review(ReviewAction.disregard),
        ),
        const SizedBox(height: 8),
        Text(
          'القبول يعني أن الملخص يطابق وصف المالك، وليس تشخيصاً.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }
}

/// The owner's own words: the written description, the recording and its transcript with its label.
class _OriginalCard extends StatelessWidget {
  const _OriginalCard({required this.description, required this.voicePath, required this.transcript, required this.label});

  final String? description;
  final String? voicePath;
  final String? transcript;
  final TranscriptLabel label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final written = (description ?? '').trim();
    final (tone, icon) = switch (label) {
      TranscriptLabel.owner => (Tone.accent, Icons.edit_rounded),
      TranscriptLabel.auto => (Tone.brand, Icons.auto_awesome_rounded),
      _ => (Tone.neutral, Icons.info_outline_rounded),
    };
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.format_quote_rounded, size: 18, color: Palette.muted),
          const SizedBox(width: 6),
          Expanded(child: Text('كما أرسله المالك، دون تعديل', style: text.bodySmall)),
        ]),
        const SizedBox(height: 8),
        Text(written.isEmpty ? 'لا يوجد وصف مكتوب.' : written, style: text.bodyLarge),
        if (voicePath != null) ...[const SizedBox(height: 12), VoicePlayer(note: VoiceNote.remote(voicePath!))],
        if (label != TranscriptLabel.none) ...[
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.notes_rounded, size: 20, color: Palette.juniper),
            const SizedBox(width: 8),
            Expanded(child: Text('نص التسجيل', style: text.titleSmall)),
            StatusPill(label.text, tone: tone, icon: icon),
          ]),
          const SizedBox(height: 8),
          Text(
            transcript ?? 'لا يوجد نص لهذا التسجيل. استمع إلى التسجيل الصوتي.',
            style: transcript == null ? text.bodyMedium!.copyWith(color: Palette.muted) : text.bodyMedium,
          ),
        ],
      ]),
    );
  }
}

/// «قبله د. سارة · 2 نوفمبر 9:40 م», with a check that pops in when the decision is made.
class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.accepted, required this.caption});

  final bool accepted;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(accepted ? Tone.success : Tone.neutral);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Icon(accepted ? Icons.check_circle_rounded : Icons.visibility_off_rounded, color: fg, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              caption,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => AppCard(
        shadow: false,
        child: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(width: 12),
          Text('جارٍ تحميل الملخص…', style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NoticeBanner(message, icon: Icons.cloud_off_rounded, tone: Tone.danger),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ),
      ]);
}

/// Accept and Disregard, side by side, or stacked when narrower than [minRowWidth]: side by side on a 360 px
/// phone their labels broke onto two lines inside the buttons.
class SummaryDecisionButtons extends StatelessWidget {
  const SummaryDecisionButtons({super.key, required this.busy, required this.onAccept, required this.onDisregard});

  static const minRowWidth = 320.0;

  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDisregard;

  @override
  Widget build(BuildContext context) {
    final accept = BusyButton(busy: busy, onPressed: onAccept, label: 'قبول الملخص', icon: Icons.check_rounded);
    final disregard = OutlinedButton.icon(
      onPressed: busy ? null : onDisregard,
      icon: const Icon(Icons.visibility_off_outlined),
      label: const Text('تجاهل الملخص'),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < minRowWidth
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [accept, const SizedBox(height: 10), disregard])
          : Row(children: [Expanded(child: accept), const SizedBox(width: 10), Expanded(child: disregard)]),
    );
  }
}
