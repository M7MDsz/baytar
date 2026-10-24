import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
          icon: const Icon(Icons.check_circle, size: 48),
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
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('1. اختر الموعد', style: Theme.of(context).textTheme.titleMedium),
          SlotPicker(
            key: _pickerKey,
            vetId: widget.vetId,
            selected: _slot?.id,
            onSelected: (s) => setState(() => _slot = s),
          ),
          const SizedBox(height: 24),
          Text('2. اختر الحالة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<BookableCase>>(
            future: _cases,
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final cases = snap.data!;
              if (cases.isEmpty) {
                return const Text('لا توجد حالة مرسلة بدون موعد. أرسل حالة لحيوانك أولاً.');
              }
              return RadioGroup<String>(
                groupValue: _caseId,
                onChanged: (v) => setState(() => _caseId = v),
                child: Column(children: [
                  for (final c in cases)
                    RadioListTile<String>(
                      value: c.id,
                      title: Text(c.animalName),
                      subtitle: Text(c.caseNumber ?? ''),
                    ),
                ]),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_slot != null) Text('الموعد المختار: ${formatDayTime(_slot!.startsAt)}', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          BusyButton(busy: _busy, onPressed: _confirm, label: 'تأكيد الحجز'),
        ]),
      );
}
