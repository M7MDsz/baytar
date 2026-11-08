import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../animals/animal.dart';

/// The case form's animal choice. Expanded to the field's width with ellipsized names: sized to its widest
/// item, a long animal name pushed the dropdown 18 px past the card on a 360 px phone.
class AnimalPicker extends StatelessWidget {
  const AnimalPicker({super.key, required this.animals, required this.value, required this.onChanged});

  final List<Animal> animals;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: InputDecoration(labelText: requiredLabel('الحيوان')),
        items: [
          for (final a in animals)
            DropdownMenuItem(
              value: a.id,
              child: Row(children: [
                SpeciesAvatar(a.species, radius: 14),
                const SizedBox(width: 10),
                Expanded(child: Text('${a.name} · ${a.speciesLabel}', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
        onChanged: onChanged,
      );
}
