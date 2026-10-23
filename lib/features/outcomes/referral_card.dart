import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import 'outcome.dart';

/// Highlights an in-person referral wherever the owner sees the case.
class ReferralCard extends StatelessWidget {
  const ReferralCard({super.key, required this.referral});

  final Referral referral;

  @override
  Widget build(BuildContext context) => Card(
        color: amber.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_hospital_outlined, color: amber),
              const SizedBox(width: 8),
              Text('إحالة لزيارة عيادة', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(formatDate(referral.createdAt), style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 10),
            Text('السبب', style: Theme.of(context).textTheme.labelLarge),
            Text(referral.reason),
            const SizedBox(height: 8),
            Text('التعليمات', style: Theme.of(context).textTheme.labelLarge),
            Text(referral.instructions),
          ]),
        ),
      );
}
