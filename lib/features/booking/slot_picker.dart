import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'booking_repository.dart';

/// A veterinarian's free slots grouped by day; exactly one can be selected.
/// Reloads every 30 seconds so slots added, removed or booked by others show within a minute.
class SlotPicker extends StatefulWidget {
  const SlotPicker({super.key, required this.vetId, required this.selected, required this.onSelected, this.excludeSlotId});

  final String vetId;
  final String? selected;
  final ValueChanged<FreeSlot?> onSelected;
  final String? excludeSlotId;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  List<FreeSlot>? _slots;
  Object? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final slots = await BookingRepository().freeSlots(widget.vetId);
      if (!mounted) return;
      setState(() {
        _slots = slots.where((s) => s.id != widget.excludeSlotId).toList();
        _error = null;
      });
      // The chosen slot was taken or removed meanwhile.
      if (widget.selected != null && !_slots!.any((s) => s.id == widget.selected)) widget.onSelected(null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _slots == null) return Text(friendlyError(_error!));
    if (_slots == null) return const Center(child: CircularProgressIndicator());
    if (_slots!.isEmpty) {
      return const EmptyState(icon: Icons.event_busy, message: 'لا توجد مواعيد متاحة لهذا الطبيب حالياً.');
    }
    final byDay = <String, List<FreeSlot>>{};
    for (final s in _slots!) {
      byDay.putIfAbsent(formatDay(s.startsAt), () => []).add(s);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final day in byDay.entries) ...[
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(day.key)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in day.value)
            ChoiceChip(
              label: Text(formatTime(s.startsAt)),
              selected: s.id == widget.selected,
              onSelected: (on) => widget.onSelected(on ? s : null),
            ),
        ]),
      ],
    ]);
  }
}
