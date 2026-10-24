import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import 'vet_summary.dart';

const availabilityLabels = <int, String>{1: 'اليوم', 3: 'خلال 3 أيام', 7: 'خلال أسبوع'};

/// US-09: choose any combination of specialty, animal type, language and availability.
class VetFiltersSheet extends StatefulWidget {
  const VetFiltersSheet({super.key, required this.initial});

  final VetFilters initial;

  @override
  State<VetFiltersSheet> createState() => _VetFiltersSheetState();
}

class _VetFiltersSheetState extends State<VetFiltersSheet> {
  late String? _specialty = widget.initial.specialty;
  late String? _animalType = widget.initial.animalType;
  late String? _language = widget.initial.language;
  late int? _withinDays = widget.initial.withinDays;

  Widget _group<T>(String title, Map<T, String> options, T? value, ValueChanged<T?> onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(title)),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final e in options.entries)
            FilterChip(
              label: Text(e.value),
              selected: value == e.key,
              onSelected: (on) => onChanged(on ? e.key : null),
            ),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('تصفية الأطباء', style: Theme.of(context).textTheme.titleLarge),
            _group('التخصص', specialtyLabels, _specialty, (v) => setState(() => _specialty = v)),
            _group('نوع الحيوان', speciesLabels, _animalType, (v) => setState(() => _animalType = v)),
            _group('اللغة', languageLabels, _language, (v) => setState(() => _language = v)),
            _group('متاح', availabilityLabels, _withinDays, (v) => setState(() => _withinDays = v)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                VetFilters(specialty: _specialty, animalType: _animalType, language: _language, withinDays: _withinDays),
              ),
              child: const Text('تطبيق'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, const VetFilters()), child: const Text('مسح الكل')),
          ]),
        ),
      );
}
