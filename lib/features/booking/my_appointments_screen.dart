import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'booking_repository.dart';
import 'owner_appointment.dart';

/// Pill colour for an appointment status: upcoming amber, completed green, cancelled red, past grey.
Tone appointmentTone(OwnerAppointment a) => switch (a.status) {
      'cancelled' => Tone.danger,
      'completed' => Tone.success,
      _ => a.isUpcoming ? Tone.accent : Tone.neutral,
    };

/// The veterinarian's avatar with a small badge of the animal's species.
class VetWithAnimal extends StatelessWidget {
  const VetWithAnimal({super.key, required this.vetGender, required this.species, this.radius = 26});

  final String? vetGender;
  final String? species;
  final double radius;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        DoctorAvatar(vetGender, radius: radius),
        PositionedDirectional(bottom: -6, end: -8, child: SpeciesAvatar(species, radius: radius * 0.5)),
      ]);
}

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

  Widget _list(List<OwnerAppointment> items, String empty, {bool findVet = false}) => items.isEmpty
      ? ListView(children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.event_note,
            message: empty,
            action: findVet
                ? FilledButton.tonalIcon(
                    style: tonalButton,
                    onPressed: () => context.go('/vets'),
                    icon: const Icon(Icons.medical_services_outlined),
                    label: const Text('الأطباء'),
                  )
                : null,
          ),
        ])
      : ListView(padding: pagePadding(context), children: [
          for (final a in items)
            ListCard(
              onTap: () => _open(a),
              leading: VetWithAnimal(vetGender: a.vetGender, species: a.animalSpecies),
              title: '${a.animalName} · ${a.vetName}',
              subtitle: formatDayTime(a.startsAt),
              trailing: StatusPill(a.statusLabel, tone: appointmentTone(a)),
            ),
        ]);

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مواعيدي'),
            actions: const [NotificationBell()],
            bottom: const PillTabBar(tabs: [Tab(text: 'القادمة'), Tab(text: 'السجل')]),
          ),
          body: AsyncView<List<OwnerAppointment>>(
            key: _key,
            load: BookingRepository().mine,
            builder: (context, all, _) {
              final upcoming = all.where((a) => a.isUpcoming).toList();
              final history = all.where((a) => !a.isUpcoming).toList().reversed.toList();
              return TabBarView(children: [
                _list(upcoming, 'لا توجد مواعيد قادمة.\nاحجز موعداً من صفحة الأطباء.', findVet: true),
                _list(history, 'لا توجد مواعيد سابقة.'),
              ]);
            },
          ),
        ),
      );
}
