import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'outcome.dart';

/// Highlights an in-person referral wherever the owner sees the case.
class ReferralCard extends StatelessWidget {
  const ReferralCard({super.key, required this.referral});

  final Referral referral;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: Palette.accentSoft,
      borderColor: Palette.accent.withValues(alpha: 0.35),
      shadow: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconTile(Icons.local_hospital_outlined, tone: Tone.accent, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text('إحالة لزيارة عيادة', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700))),
          Text(formatDate(referral.createdAt), style: text.bodySmall),
        ]),
        const SizedBox(height: 12),
        Text('السبب', style: text.labelLarge!.copyWith(color: Palette.accentDeep)),
        const SizedBox(height: 2),
        Text(referral.reason, style: text.bodyMedium),
        const SizedBox(height: 10),
        Text('التعليمات', style: text.labelLarge!.copyWith(color: Palette.accentDeep)),
        const SizedBox(height: 2),
        Text(referral.instructions, style: text.bodyMedium),
      ]),
    );
  }
}
