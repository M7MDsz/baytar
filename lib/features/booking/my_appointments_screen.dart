import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'booking_repository.dart';
import 'owner_appointment.dart';

/// US-11: the owner's upcoming appointments, plus the record of past and cancelled ones.
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  Key _key = UniqueKey();

  Future<void> _open(OwnerAppointment a) async {
    await context.push('/appointments/${a.id}');
    setState(() => _key = UniqueKey());
  }

  Widget _list(List<OwnerAppointment> items, String empty) => items.isEmpty
      ? ListView(children: [const SizedBox(height: 100), EmptyState(icon: Icons.event_note, message: empty)])
      : ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in items)
            Card(
              child: ListTile(
                onTap: () => _open(a),
                leading: const Icon(Icons.video_camera_front_outlined),
                title: Text('${a.animalName} · ${a.vetName}'),
                subtitle: Text(formatDayTime(a.startsAt)),
                trailing: Chip(label: Text(a.statusLabel)),
              ),
            ),
        ]);

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مواعيدي'),
            bottom: const TabBar(tabs: [Tab(text: 'القادمة'), Tab(text: 'السجل')]),
          ),
          body: AsyncView<List<OwnerAppointment>>(
            key: _key,
            load: BookingRepository().mine,
            builder: (context, all, _) {
              final upcoming = all.where((a) => a.isUpcoming).toList();
              final history = all.where((a) => !a.isUpcoming).toList().reversed.toList();
              return TabBarView(children: [
                _list(upcoming, 'لا توجد مواعيد قادمة.\nاحجز موعداً من صفحة الأطباء.'),
                _list(history, 'لا توجد مواعيد سابقة.'),
              ]);
            },
          ),
        ),
      );
}
