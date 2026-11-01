import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'info_request.dart';

/// One information request with its status and the owner's answer.
class InfoRequestCard extends StatelessWidget {
  const InfoRequestCard({super.key, required this.request, this.action});

  final InfoRequest request;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(Icons.help_outline_rounded, tone: r.isOpen ? Tone.accent : Tone.success, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text('طلب معلومات · ${formatDayTime(r.createdAt)}', style: text.titleSmall)),
          const SizedBox(width: 8),
          StatusPill(r.isOpen ? 'بانتظار الرد' : 'تم الرد', tone: r.isOpen ? Tone.accent : Tone.success),
        ]),
        const SizedBox(height: 10),
        Text(r.message, style: text.bodyMedium),
        if (r.response != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.canvas,
              borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(color: Palette.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رد المالك:', style: text.labelLarge!.copyWith(color: Palette.muted)),
              const SizedBox(height: 4),
              Text(r.response!, style: text.bodyMedium),
            ]),
          ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ]),
    );
  }
}
