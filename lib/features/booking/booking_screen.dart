import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'booking_repository.dart';
import 'slot_picker.dart';

/// Path used by the veterinarian profile (US-10) to start a booking.
String bookingPath(String vetId, {String? vetName}) =>
    '/book/$vetId${vetName == null ? '' : '?name=${Uri.encodeComponent(vetName)}'}';

/// US-11: pick one free slot and one submitted case, then confirm.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.vetId, this.vetName});

  final String vetId;
  final String? vetName;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _repo = BookingRepository();
  late final Future<List<BookableCase>> _cases = _repo.bookableCases();
  FreeSlot? _slot;
  String? _caseId;
  bool _busy = false;
  Key _pickerKey = UniqueKey();

  Future<void> _confirm() async {
    if (_slot == null || _caseId == null) {
      showSnack(context, 'اختر الموعد والحالة أولاً', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.book(slotId: _slot!.id, caseId: _caseId!);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const SuccessCheck(),
          title: const Text('تم تأكيد الحجز'),
          content: Text('موعدك ${formatDayTime(_slot!.startsAt)}${widget.vetName == null ? '' : ' مع ${widget.vetName}'}.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      if (mounted) context.go('/appointments');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e, bookingErrors), error: true);
      // Show the current free slots so the owner can choose another one.
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
        appBar: AppBar(title: Text(widget.vetName == null ? 'حجز موعد' : 'حجز موعد مع ${widget.vetName}')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          SectionCard(
            title: '1. اختر الموعد',
            icon: Icons.schedule,
            child: SlotPicker(
              key: _pickerKey,
              vetId: widget.vetId,
              selected: _slot?.id,
              onSelected: (s) => setState(() => _slot = s),
            ),
          ),
          SectionCard(
            title: '2. اختر الحالة',
            icon: Icons.assignment_outlined,
            child: FutureBuilder<List<BookableCase>>(
              future: _cases,
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final cases = snap.data!;
                if (cases.isEmpty) {
                  return const NoticeBanner('لا توجد حالة مرسلة بدون موعد. أرسل حالة لحيوانك أولاً.', tone: Tone.neutral);
                }
                return RadioGroup<String>(
                  groupValue: _caseId,
                  onChanged: (v) => setState(() => _caseId = v),
                  child: Column(children: [
                    for (final c in cases)
                      _Choice(
                        selected: _caseId == c.id,
                        child: RadioListTile<String>(
                          value: c.id,
                          title: Text(c.animalName),
                          subtitle: Text(c.caseNumber ?? ''),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        ]),
        bottomNavigationBar: BottomActionBar(children: [
          if (_slot != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.event_available, size: 18, color: Palette.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'الموعد المختار: ${formatDayTime(_slot!.startsAt)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ]),
            ),
          BusyButton(busy: _busy, onPressed: _confirm, label: 'تأكيد الحجز'),
        ]),
      );
}

/// Bordered option row that turns juniper when chosen.
class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? Palette.juniperSoft : Palette.surface,
          borderRadius: BorderRadius.circular(Radii.tile),
          border: Border.all(color: selected ? Palette.juniper : Palette.line, width: selected ? 1.6 : 1),
        ),
        child: child,
      );
}
