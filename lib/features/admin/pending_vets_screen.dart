import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'pending_vet.dart';

Future<List<PendingVet>> loadPendingVets() async {
  final rows = await db.rpc('pending_vets') as List;
  return rows.map((r) => PendingVet(r as Map<String, dynamic>)).toList();
}

/// US-32: pending registrations, oldest first. Administrator start page.
class PendingVetsScreen extends StatefulWidget {
  const PendingVetsScreen({super.key});

  @override
  State<PendingVetsScreen> createState() => _PendingVetsScreenState();
}

class _PendingVetsScreenState extends State<PendingVetsScreen> {
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('طلبات التحقق'), actions: const [NotificationBell()]),
        body: AsyncView<List<PendingVet>>(
          key: _key,
          load: loadPendingVets,
          builder: (context, items, _) => items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 100),
                  EmptyState(icon: Icons.task_alt, message: 'لا توجد طلبات بانتظار التحقق.'),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  for (final v in items)
                    ListCard(
                      leading: DoctorAvatar(v.gender, radius: 26),
                      title: v.fullName,
                      subtitle: 'ترخيص ${v.licenseNumber}\nأُرسل ${formatDayTime(v.submittedAt)}',
                      onTap: () async {
                        await context.push('/admin/vets/${v.id}');
                        setState(() => _key = UniqueKey());
                      },
                    ),
                ]),
        ),
      );
}
