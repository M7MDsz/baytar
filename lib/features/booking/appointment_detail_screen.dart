import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../consultation/consultation_feature.dart';
import '../consultation/join_window.dart';
import 'booking_repository.dart';
import 'owner_appointment.dart';

/// Owner's appointment page: details, Join (US-14) and the outcome once approved (US-16).
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الموعد')),
        body: AsyncView<OwnerAppointment>(
          load: () => BookingRepository().byId(widget.appointmentId),
          builder: (context, a, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow('الموعد', formatDayTime(a.startsAt)),
                  InfoRow('الطبيب', a.vetName),
                  InfoRow('الحيوان', a.animalName),
                  InfoRow('رقم الحالة', a.caseNumber),
                  InfoRow('الحالة', a.statusLabel),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (a.status == 'booked' && a.isUpcoming)
              FilledButton.icon(
                onPressed: () {
                  final blocked = joinBlockedReason(a.startsAt, UserRole.owner);
                  blocked == null
                      ? context.push(consultationPath(a.id))
                      : showSnack(context, joinRefusedText[blocked]!);
                },
                icon: const Icon(Icons.video_call),
                label: const Text('الانضمام إلى الاستشارة'),
              ),
            if (a.hasOutcome)
              OutlinedButton.icon(
                onPressed: () => context.push('/outcomes/${a.id}'),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('عرض نتيجة الاستشارة'),
              ),
          ]),
        ),
      );
}
