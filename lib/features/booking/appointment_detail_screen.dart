import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../consultation/consultation_feature.dart';
import '../consultation/join_window.dart';
import '../reschedule/appointment_change.dart';
import 'booking_repository.dart';
import 'owner_appointment.dart';

/// Owner's appointment page: details, Join (US-14), Reschedule (US-12), Cancel (US-13)
/// and the outcome once approved (US-16).
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Key _key = UniqueKey();

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'إلغاء الموعد',
      message: 'هل تريد إلغاء هذا الموعد؟ سيصبح الوقت متاحاً لغيرك.',
      confirmLabel: 'تأكيد الإلغاء',
      destructive: true,
    );
    if (!ok) return;
    try {
      await db.rpc('cancel_appointment', params: {'p_appointment': widget.appointmentId});
      if (!mounted) return;
      showSnack(context, 'تم إلغاء الموعد');
      setState(() => _key = UniqueKey());
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, changeErrors), error: true);
    }
  }

  Future<void> _reschedule() async {
    final changed = await context.push<bool>('/appointments/${widget.appointmentId}/reschedule');
    if (changed == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الموعد')),
        body: AsyncView<OwnerAppointment>(
          key: _key,
          load: () => BookingRepository().byId(widget.appointmentId),
          builder: (context, a, reload) {
            final changeable = canChangeAppointment(a);
            return ListView(padding: const EdgeInsets.all(16), children: [
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
              if (changeable) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _reschedule, icon: const Icon(Icons.edit_calendar), label: const Text('تغيير الموعد')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.event_busy),
                  label: const Text('إلغاء الموعد'),
                ),
              ] else if (a.status == 'booked' && a.isUpcoming)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('لا يمكن تغيير الموعد أو إلغاؤه قبل بدايته بأقل من 12 ساعة.', textAlign: TextAlign.center),
                ),
              if (a.hasOutcome)
                OutlinedButton.icon(
                  onPressed: () => context.push('/outcomes/${a.id}'),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('عرض نتيجة الاستشارة'),
                ),
            ]);
          },
        ),
      );
}
