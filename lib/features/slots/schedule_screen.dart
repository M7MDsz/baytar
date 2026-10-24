import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';

const _slotErrors = {
  'vet_not_verified': 'لا يمكنك نشر مواعيد قبل التحقق من ترخيصك.',
  'slot_in_past': 'لا يمكن إضافة موعد في وقت مضى.',
  'slot_overlaps': 'يتداخل هذا الموعد مع موعد آخر لك.',
  'slot_booked': 'لا يمكن حذف موعد محجوز.',
};

class _Slot {
  _Slot(Map<String, dynamic> m)
      : id = m['id'] as String,
        startsAt = parseTs(m['starts_at']),
        booked = m['booked'] as bool;

  final String id;
  final DateTime startsAt;
  final bool booked;
}

/// US-33: the veterinarian adds 30-minute slots (optionally weekly) and removes free ones.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Key _key = UniqueKey();

  Future<List<_Slot>> _load() async {
    final rows = await db.rpc('my_schedule') as List;
    return rows.map((r) => _Slot(r as Map<String, dynamic>)).toList();
  }

  void _refresh() => setState(() => _key = UniqueKey());

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddSlotSheet(),
    );
    if (added == true) _refresh();
  }

  Future<void> _remove(_Slot s) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف الموعد',
      message: 'حذف موعد ${formatDayTime(s.startsAt)}؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!ok) return;
    try {
      await db.rpc('delete_slot', params: {'p_slot': s.id});
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, _slotErrors), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('جدول مواعيدي')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('إضافة موعد'),
        ),
        body: AsyncView<List<_Slot>>(
          key: _key,
          load: _load,
          builder: (context, slots, _) {
            if (slots.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(icon: Icons.schedule, message: 'لم تنشر أي مواعيد بعد.'),
              ]);
            }
            final scheme = Theme.of(context).colorScheme;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
              for (final s in slots)
                Card(
                  color: s.booked ? scheme.secondaryContainer : null,
                  child: ListTile(
                    leading: Icon(s.booked ? Icons.event_busy : Icons.event_available),
                    title: Text(formatDayTime(s.startsAt)),
                    subtitle: Text(s.booked ? 'محجوز' : 'متاح'),
                    trailing: s.booked
                        ? null
                        : IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(s)),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _AddSlotSheet extends StatefulWidget {
  const _AddSlotSheet();

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  DateTime? _day;
  TimeOfDay? _time;
  int _weeks = 0;
  bool _busy = false;

  DateTime? get _start => _day == null || _time == null
      ? null
      : DateTime(_day!.year, _day!.month, _day!.day, _time!.hour, _time!.minute);

  Future<void> _save() async {
    final start = _start;
    if (start == null) return;
    if (!start.isAfter(DateTime.now())) {
      showSnack(context, _slotErrors['slot_in_past']!, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await db.rpc('add_slots', params: {'p_starts_at': start.toUtc().toIso8601String(), 'p_weeks': _weeks});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, _slotErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('موعد جديد (30 دقيقة)', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(_day == null ? 'اختر اليوم' : formatDay(_day!)),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _day ?? now,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 60)),
            );
            if (d != null) setState(() => _day = d);
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time),
          label: Text(_time == null ? 'اختر وقت البداية' : _time!.format(context)),
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 17, minute: 0));
            if (t != null) setState(() => _time = t);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _weeks,
          decoration: const InputDecoration(labelText: 'التكرار أسبوعياً'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('بدون تكرار')),
            DropdownMenuItem(value: 1, child: Text('أسبوع واحد إضافي')),
            DropdownMenuItem(value: 2, child: Text('أسبوعان إضافيان')),
            DropdownMenuItem(value: 3, child: Text('3 أسابيع إضافية')),
            DropdownMenuItem(value: 4, child: Text('4 أسابيع إضافية')),
          ],
          onChanged: (v) => setState(() => _weeks = v ?? 0),
        ),
        const SizedBox(height: 20),
        BusyButton(busy: _busy, onPressed: _start == null ? null : _save, label: 'إضافة'),
      ]),
    );
  }
}
