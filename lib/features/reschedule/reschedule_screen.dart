import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../booking/booking_repository.dart';
import '../booking/owner_appointment.dart';
import '../booking/slot_picker.dart';
import 'appointment_change.dart';

/// US-12: choose another free slot of the same veterinarian. Nothing changes until Confirm succeeds.
class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  FreeSlot? _slot;
  bool _busy = false;
  Key _pickerKey = UniqueKey();

  Future<void> _confirm(OwnerAppointment a) async {
    if (_slot == null) return;
    setState(() => _busy = true);
    try {
      await db.rpc('reschedule_appointment', params: {'p_appointment': a.id, 'p_new_slot': _slot!.id});
      if (!mounted) return;
      showSnack(context, 'تم تغيير الموعد إلى ${formatDayTime(_slot!.startsAt)}');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, '${friendlyError(e, changeErrors)}\nموعدك الأصلي لم يتغير.', error: true);
      setState(() {
        _slot = null;
        _pickerKey = UniqueKey();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تغيير الموعد')),
        body: AsyncView<OwnerAppointment>(
          load: () => BookingRepository().byId(widget.appointmentId),
          builder: (context, a, _) => ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: ListTile(title: const Text('الموعد الحالي'), subtitle: Text('${formatDayTime(a.startsAt)} · ${a.vetName}'))),
            const SizedBox(height: 12),
            Text('المواعيد المتاحة', style: Theme.of(context).textTheme.titleMedium),
            SlotPicker(
              key: _pickerKey,
              vetId: a.vetId,
              selected: _slot?.id,
              onSelected: (s) => setState(() => _slot = s),
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _slot == null ? null : () => _confirm(a), label: 'تأكيد الموعد الجديد'),
          ]),
        ),
      );
}
