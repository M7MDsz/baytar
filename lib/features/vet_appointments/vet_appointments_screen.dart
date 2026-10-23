import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../consultation/join_window.dart';
import 'vet_appointment.dart';

/// Paths owned by other stories: the veterinarian's case page (US-17) and video room (US-19).
String vetCasePath(String caseId) => '/vet/cases/$caseId';
String vetConsultationPath(String appointmentId) => '/vet/consultation/$appointmentId';

Future<List<VetAppointment>> loadVetAppointments() async {
  final rows = await db.rpc('vet_upcoming_appointments') as List;
  return rows.map((r) => VetAppointment.fromMap(r as Map<String, dynamic>)).toList();
}

/// US-34: veterinarian start page.
class VetAppointmentsScreen extends StatefulWidget {
  const VetAppointmentsScreen({super.key});

  @override
  State<VetAppointmentsScreen> createState() => _VetAppointmentsScreenState();
}

class _VetAppointmentsScreenState extends State<VetAppointmentsScreen> {
  Key _key = UniqueKey();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh every minute so new bookings, cancellations and the Join button appear on time.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _key = UniqueKey()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مواعيدي القادمة')),
        body: AsyncView<List<VetAppointment>>(
          key: _key,
          load: loadVetAppointments,
          builder: (context, items, _) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(icon: Icons.event_available, message: 'No upcoming appointments\nلا توجد مواعيد قادمة'),
              ]);
            }
            final now = DateTime.now();
            final today = items.where((a) => isSameDay(a.startsAt, now)).toList();
            final later = items.where((a) => !isSameDay(a.startsAt, now)).toList();
            return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              if (today.isNotEmpty) ...[
                const SectionTitle('اليوم'),
                for (final a in today) _AppointmentTile(a, showDay: false),
              ],
              if (later.isNotEmpty) ...[
                const SectionTitle('القادمة'),
                for (final a in later) _AppointmentTile(a, showDay: true),
              ],
            ]);
          },
        ),
      );
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile(this.a, {required this.showDay});

  final VetAppointment a;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final canJoin = canJoinNow(a.startsAt, UserRole.vet);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => context.push(vetCasePath(a.caseId)),
        leading: CircleAvatar(child: Text(formatTime(a.startsAt).split(' ').first)),
        title: Text('${a.animalName} · ${a.speciesLabel}'),
        subtitle: Text('${showDay ? formatDayTime(a.startsAt) : formatTime(a.startsAt)}\nالمالك: ${a.ownerFirstName}'),
        isThreeLine: true,
        trailing: canJoin
            ? FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => context.push(vetConsultationPath(a.id)),
                child: const Text('انضمام'),
              )
            : const Icon(Icons.chevron_left),
      ),
    );
  }
}
