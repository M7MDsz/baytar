import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../consultation/join_window.dart';
import '../notifications/notification_bell.dart';
import '../vet_appointments/vet_appointment.dart';
import '../vet_appointments/vet_appointments_screen.dart';

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

/// Everything the agenda shows: the vet's slots (my_schedule), the booked appointments with their
/// animal and owner (vet_upcoming_appointments), and the next appointment's case number.
class _Agenda {
  const _Agenda(this.slots, this.appointments, this.nextCaseNumber);

  final List<_Slot> slots;
  final List<VetAppointment> appointments;
  final String? nextCaseNumber;

  VetAppointment? appointmentAt(DateTime startsAt) =>
      appointments.where((a) => a.startsAt.isAtSameMomentAs(startsAt)).firstOrNull;
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

final _weekday = DateFormat('EEEE', 'ar');
final _dayNumber = DateFormat('d', 'ar');

/// «موعد واحد»، «موعدان»، «٣ مواعيد»، «١١ موعداً».
String _slotsLabel(int n) => switch (n) {
      1 => 'موعد واحد',
      2 => 'موعدان',
      _ when n <= 10 => '${arabicDigits(n)} مواعيد',
      _ => '${arabicDigits(n)} موعداً',
    };

/// «الآن» inside the join window, otherwise «بعد …» in minutes, hours or days.
String _countdown(DateTime startsAt) {
  if (canJoinNow(startsAt, UserRole.vet)) return 'الآن';
  final d = startsAt.difference(DateTime.now());
  if (d.inMinutes < 60) return 'بعد ${arabicDigits(d.inMinutes.clamp(1, 59))} دقيقة';
  if (d.inHours < 24) {
    final h = d.inHours;
    return switch (h) {
      1 => 'بعد ساعة',
      2 => 'بعد ساعتين',
      _ when h <= 10 => 'بعد ${arabicDigits(h)} ساعات',
      _ => 'بعد ${arabicDigits(h)} ساعة',
    };
  }
  final days = _dayOf(startsAt).difference(_dayOf(DateTime.now())).inDays;
  return switch (days) {
    1 => 'بعد يوم',
    2 => 'بعد يومين',
    _ => 'بعد ${arabicDigits(days)} أيام',
  };
}

/// US-33: the veterinarian's agenda. Adds 30-minute slots (optionally weekly) and removes free ones.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Key _key = UniqueKey();
  DateTime? _day;

  Future<_Agenda> _load() async {
    final rows = await db.rpc('my_schedule') as List;
    final slots = rows.map((r) => _Slot(r as Map<String, dynamic>)).toList();
    final appointments = await loadVetAppointments();
    String? caseNumber;
    if (appointments.isNotEmpty) {
      final c = await db.from('cases').select('case_number').eq('id', appointments.first.caseId).maybeSingle();
      caseNumber = c?['case_number'] as String?;
    }
    return _Agenda(slots, appointments, caseNumber);
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
        appBar: AppBar(title: const Text('جدول مواعيدي'), actions: const [NotificationBell()]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة موعد'),
        ),
        body: AsyncView<_Agenda>(
          key: _key,
          load: _load,
          builder: (context, agenda, _) {
            final today = _dayOf(DateTime.now());
            final slotDays = agenda.slots.map((s) => _dayOf(s.startsAt)).toSet();
            final last = slotDays.isEmpty ? today : slotDays.reduce((a, b) => a.isAfter(b) ? a : b);
            final dayCount = last.difference(today).inDays + 1;
            final days = [for (var i = 0; i < (dayCount < 7 ? 7 : dayCount); i++) today.add(Duration(days: i))];
            // Default to the first day that has slots, so the agenda opens on something useful.
            final firstWithSlots = days.where(slotDays.contains).firstOrNull ?? today;
            final day = _day != null && days.contains(_day) ? _day! : firstWithSlots;
            final daySlots = agenda.slots.where((s) => _dayOf(s.startsAt) == day).toList();
            final bookedDays = agenda.slots.where((s) => s.booked).map((s) => _dayOf(s.startsAt)).toSet();
            final next = agenda.appointments.firstOrNull;
            return ListView(padding: pagePadding(context, bottom: 96), children: [
              if (next != null) _NextAppointment(next, caseNumber: agenda.nextCaseNumber),
              const SizedBox(height: 8),
              _DayStrip(days: days, selected: day, booked: bookedDays, onSelect: (d) => setState(() => _day = d)),
              if (agenda.slots.isEmpty)
                const EmptyState(
                  icon: Icons.schedule,
                  illustration: SpeciesCluster(['cat', 'dog', 'horse']),
                  message: 'لم تنشر أي مواعيد بعد.',
                )
              else if (daySlots.isEmpty)
                EmptyState(
                  icon: Icons.event_available_rounded,
                  illustration: const SpeciesCluster(['cat', 'dog', 'horse']),
                  message: 'أضف أوقاتاً متاحة',
                  action: FilledButton.tonalIcon(
                    style: tonalButton,
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة موعد'),
                  ),
                )
              else ...[
                _DaySummary(daySlots),
                for (final (title, part) in [
                  ('الصباح', daySlots.where((s) => s.startsAt.hour < 12).toList()),
                  ('المساء', daySlots.where((s) => s.startsAt.hour >= 12).toList()),
                ])
                  if (part.isNotEmpty) ...[
                    SectionTitle(title),
                    for (final s in part)
                      _AgendaRow(
                        slot: s,
                        appointment: s.booked ? agenda.appointmentAt(s.startsAt) : null,
                        onDelete: () => _remove(s),
                      ),
                  ],
              ],
            ]);
          },
        ),
      );
}

/// The next booked consultation: animal, owner, time, countdown, case number and the right action.
class _NextAppointment extends StatelessWidget {
  const _NextAppointment(this.a, {required this.caseNumber});

  final VetAppointment a;
  final String? caseNumber;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canJoin = canJoinNow(a.startsAt, UserRole.vet);
    const onDark = TextStyle(color: Colors.white);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Palette.juniperMid, Palette.juniper],
        ),
        boxShadow: softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('الموعد القادم', style: text.labelLarge!.copyWith(color: Colors.white70)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: canJoin ? Palette.accent : Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_countdown(a.startsAt), style: text.labelMedium!.merge(onDark).copyWith(fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          SpeciesAvatar(a.species, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.animalName} · ${a.speciesLabel}', style: text.titleMedium!.merge(onDark).copyWith(fontWeight: FontWeight.w700)),
              Text('المالك: ${a.ownerFirstName}', style: text.bodyMedium!.copyWith(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(formatDayTime(a.startsAt), style: text.bodyMedium!.merge(onDark)),
            ]),
          ),
        ]),
        if (caseNumber != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tag_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(caseNumber!, style: text.labelMedium!.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        canJoin
            ? FilledButton.icon(
                onPressed: () => context.push(vetConsultationPath(a.id)),
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('الانضمام إلى الاستشارة'),
              )
            : FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Palette.juniper),
                onPressed: () => context.push(vetCasePath(a.caseId)),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('تفاصيل الحالة'),
              ),
      ]),
    );
  }
}

/// Horizontally scrolling day chips; the chosen day is emerald and days with bookings carry a dot.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days, required this.selected, required this.booked, required this.onSelect});

  final List<DateTime> days;
  final DateTime selected;
  final Set<DateTime> booked;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final on = d == selected;
          final name = switch (i) { 0 => 'اليوم', 1 => 'غداً', _ => _weekday.format(d) };
          return Semantics(
            button: true,
            selected: on,
            child: InkWell(
              onTap: () => onSelect(d),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 66,
                decoration: BoxDecoration(
                  color: on ? Palette.accent : Palette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? Palette.accent : Palette.line),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall!.copyWith(fontSize: 11, color: on ? Colors.white : Palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dayNumber.format(d),
                    style: text.titleLarge!.copyWith(color: on ? Colors.white : Palette.ink, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: booked.contains(d) ? (on ? Colors.white : Palette.accent) : Colors.transparent,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// «٦ مواعيد · ١ محجوز · ٥ متاح» for the chosen day.
class _DaySummary extends StatelessWidget {
  const _DaySummary(this.slots);

  final List<_Slot> slots;

  @override
  Widget build(BuildContext context) {
    final booked = slots.where((s) => s.booked).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        '${_slotsLabel(slots.length)} · ${arabicDigits(booked)} محجوز · ${arabicDigits(slots.length - booked)} متاح',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Palette.muted),
      ),
    );
  }
}

/// One slot on the agenda: the time on the start side, then a rich card when booked or a slim row when free.
class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.slot, required this.appointment, required this.onDelete});

  final _Slot slot;
  final VetAppointment? appointment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = appointment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 70,
          child: Text(
            formatTime(slot.startsAt),
            style: text.labelLarge!.copyWith(color: slot.booked ? Palette.ink : Palette.muted),
          ),
        ),
        Expanded(
          child: slot.booked
              ? AppCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
                  onTap: a == null ? null : () => context.push(vetCasePath(a.caseId)),
                  child: Row(children: [
                    SpeciesAvatar(a?.species, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (a != null) ...[
                          Text(a.animalName, style: text.titleSmall),
                          Text('المالك: ${a.ownerFirstName}', style: text.bodySmall),
                        ],
                        if (a == null) const StatusPill('محجوز', tone: Tone.accent, dot: true),
                      ]),
                    ),
                    if (a != null) ...[
                      const StatusPill('محجوز', tone: Tone.accent, dot: true),
                      const Icon(Icons.chevron_right_rounded, color: Palette.muted),
                    ],
                  ]),
                )
              : Container(
                  height: 48,
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  decoration: BoxDecoration(
                    color: Palette.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(Radii.tile),
                    border: Border.all(color: Palette.lineStrong.withValues(alpha: 0.7)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_available_rounded, size: 18, color: Palette.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text('متاح', style: text.bodyMedium!.copyWith(color: Palette.muted))),
                    PopupMenuButton<void>(
                      tooltip: 'خيارات',
                      icon: const Icon(Icons.more_horiz_rounded, color: Palette.muted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          onTap: onDelete,
                          child: Row(children: [
                            const Icon(Icons.delete_outline_rounded, color: Palette.danger, size: 20),
                            const SizedBox(width: 10),
                            Text('حذف', style: text.bodyMedium!.copyWith(color: Palette.danger)),
                          ]),
                        ),
                      ],
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
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
    final fieldStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconTile(Icons.add_alarm_rounded, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text('موعد جديد (30 دقيقة)', style: Theme.of(context).textTheme.titleLarge)),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          style: fieldStyle,
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
          style: fieldStyle,
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
