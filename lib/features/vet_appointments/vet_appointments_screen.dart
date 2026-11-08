import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../consultation/join_window.dart';
import '../notifications/notification_bell.dart';
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
        appBar: AppBar(title: const Text('مواعيدي القادمة'), actions: const [NotificationBell()]),
        body: AsyncView<List<VetAppointment>>(
          key: _key,
          load: loadVetAppointments,
          builder: (context, items, _) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(icon: Icons.event_available, message: 'لا توجد مواعيد قادمة'),
              ]);
            }
            final now = DateTime.now();
            final today = items.where((a) => isSameDay(a.startsAt, now)).toList();
            final later = items.where((a) => !isSameDay(a.startsAt, now)).toList();
            return ListView(padding: pagePadding(context, top: 0), children: [
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
    return ListCard(
      onTap: () => context.push(vetCasePath(a.caseId)),
      color: canJoin ? Palette.accentSoft.withValues(alpha: 0.45) : Palette.surface,
      borderColor: canJoin ? Palette.accent.withValues(alpha: 0.5) : Palette.line,
      leading: SpeciesAvatar(a.species, radius: 26),
      title: '${a.animalName} · ${a.speciesLabel}',
      subtitle: '${showDay ? formatDayTime(a.startsAt) : formatTime(a.startsAt)}\nالمالك: ${a.ownerFirstName}',
      trailing: canJoin
          ? FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: () => context.push(vetConsultationPath(a.id)),
              child: const Text('انضمام'),
            )
          : null,
    );
  }
}
