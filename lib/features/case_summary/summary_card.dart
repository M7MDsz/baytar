import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';
import 'model/case_summary.dart';

/// The one-value rows of a summary, in reading order. Fields the owner's description does not mention are left out.
List<(String, SummaryItem)> summaryFields(SummaryContent c) => [
      if (c.chiefComplaint != null) ('الشكوى الرئيسية', c.chiefComplaint!),
      if (c.duration != null) ('المدة', c.duration!),
      if (c.onset != null) ('البداية', c.onset!),
      if (c.affectedArea != null) ('المنطقة المصابة', c.affectedArea!),
    ];

/// What the card says instead of a summary; null when there is a summary to show.
String? summaryStateMessage(SummaryStatus status, SummaryContent? content) {
  if (status.hasContent) {
    return content == null || content.isEmpty ? 'تعذّر عرض محتوى الملخص. اعتمد على وصف المالك الأصلي.' : null;
  }
  return switch (status) {
    SummaryStatus.pending => 'جارٍ إعداد الملخص…',
    SummaryStatus.notGenerated => 'تعذّر إنشاء ملخص: الوصف لا يذكر أعراضاً',
    SummaryStatus.failed => 'تعذّر إنشاء الملخص هذه المرة. اعتمد على وصف المالك الأصلي.',
    SummaryStatus.disregarded => 'تم تجاهل هذا الملخص فلا يُعرض. اعتمد على وصف المالك الأصلي.',
    _ => 'لا يوجد ملخص بالذكاء الاصطناعي لهذه الحالة. اعتمد على وصف المالك الأصلي.',
  };
}

/// The review pill: waiting, accepted or disregarded. A disregarded summary is never shown as accepted.
(String, Tone, IconData)? summaryReviewPill(SummaryStatus status) => switch (status) {
      SummaryStatus.generated => ('بانتظار مراجعتك', Tone.accent, Icons.schedule_rounded),
      SummaryStatus.accepted => ('مقبول', Tone.success, Icons.check_circle_rounded),
      SummaryStatus.disregarded => ('تم تجاهله', Tone.neutral, Icons.visibility_off_outlined),
      _ => null,
    };

/// US-24: the AI-structured summary of a sent case, for the veterinarian. Always labelled advisory and not a
/// diagnosis; every item shows the owner's own words it came from. Pure display: the caller loads the data.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.content, required this.status});

  final SummaryContent? content;
  final SummaryStatus status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = summaryStateMessage(status, content);
    final pill = summaryReviewPill(status);
    final rows = <Widget>[];
    if (message == null) {
      final c = content!;
      for (final (label, item) in summaryFields(c)) {
        rows.add(_FieldRow(label: label, item: item));
      }
      if (c.symptoms.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text('الأعراض', style: text.bodyMedium!.copyWith(color: Palette.muted)),
        ));
        rows.addAll(c.symptoms.map((s) => _SymptomRow(item: s)));
      }
    }
    return AppCard(
      borderColor: Palette.accent.withValues(alpha: 0.28),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconTile(Icons.auto_awesome_rounded, tone: Tone.accent, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ملخص بالذكاء الاصطناعي · استرشادي', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('مرتّب من كلام المالك فقط', style: text.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          const StatusPill('ليس تشخيصاً', icon: Icons.info_outline_rounded),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: pill == null
                ? const SizedBox.shrink()
                : StatusPill(pill.$1, key: ValueKey(status), tone: pill.$2, icon: pill.$3),
          ),
        ]),
        if (message != null) ...[
          const SizedBox(height: 14),
          _StateMessage(message: message, busy: status == SummaryStatus.pending),
          const SizedBox(height: 4),
        ] else ...[
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) _Reveal(index: i, child: rows[i]),
        ],
      ]),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.item});

  final String label;
  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 108, child: Text(label, style: text.bodyMedium!.copyWith(color: Palette.muted))),
        Expanded(child: _ValueWithQuote(item: item)),
      ]),
    );
  }
}

class _SymptomRow extends StatelessWidget {
  const _SymptomRow({required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 9),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Palette.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: _ValueWithQuote(item: item)),
        ]),
      );
}

/// The AI's phrase, with the owner's own words under it so the veterinarian can trust where it came from.
class _ValueWithQuote extends StatelessWidget {
  const _ValueWithQuote({required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.value, style: text.bodyMedium!.copyWith(color: Palette.ink, fontWeight: FontWeight.w600)),
      if (item.quote != null) ...[
        const SizedBox(height: 2),
        Text('«${item.quote}»', style: text.bodySmall),
      ],
    ]);
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, required this.busy});

  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.surfaceMuted, borderRadius: BorderRadius.circular(Radii.tile)),
        child: Row(children: [
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
          else
            const Icon(Icons.info_outline_rounded, size: 20, color: Palette.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

/// Fades and slides a row in, a little after the one before it. Plays once; skipped when animations are off.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final delay = 70 * index.clamp(0, 8);
    final total = delay + 380;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
    );
  }
}
