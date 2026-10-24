import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import 'info_request.dart';

/// One information request with its status and the owner's answer.
class InfoRequestCard extends StatelessWidget {
  const InfoRequestCard({super.key, required this.request, this.action});

  final InfoRequest request;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.help_outline),
            const SizedBox(width: 8),
            Expanded(child: Text('طلب معلومات · ${formatDayTime(r.createdAt)}')),
            Chip(label: Text(r.isOpen ? 'بانتظار الرد' : 'تم الرد')),
          ]),
          const SizedBox(height: 6),
          Text(r.message),
          if (r.response != null) ...[
            const Divider(),
            Text('رد المالك:', style: Theme.of(context).textTheme.labelLarge),
            Text(r.response!),
          ],
          ?action,
        ]),
      ),
    );
  }
}
