import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'treatment_note.dart';

/// US-37: one issued treatment note: the veterinarian's name, license number and issue date, the care instructions
/// and the medicines. Read-only for everyone; a note that a later one corrects is marked as replaced.
class TreatmentNoteCard extends StatelessWidget {
  const TreatmentNoteCard({super.key, required this.note, this.replaced = false, this.onCorrect});

  final TreatmentNote note;
  final bool replaced;

  /// The veterinarian's "issue a correction"; null for the owner.
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final instructions = (note.careInstructions ?? '').trim();
    return AppCard(
      color: replaced ? Palette.surfaceMuted : Palette.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconTile(Icons.medication_outlined, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note.correctsNoteId == null ? 'ملاحظة علاج' : 'ملاحظة علاج (تصحيح)',
                  style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('صدرت ${formatDayTime(note.issuedAt)}', style: text.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (replaced)
            const StatusPill('صدر تصحيح لها', tone: Tone.neutral, icon: Icons.history_rounded)
          else
            const StatusPill('نهائية، لا تُعدّل', tone: Tone.success, icon: Icons.lock_outline_rounded),
        ]),
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('تعليمات العناية', style: text.bodyMedium!.copyWith(color: Palette.muted)),
          const SizedBox(height: 4),
          SelectableText(instructions, style: text.bodyLarge),
        ],
        if (note.medicines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('الأدوية', style: text.bodyMedium!.copyWith(color: Palette.muted)),
          for (final m in note.medicines) _MedicineRow(medicine: m),
        ],
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),
        Text('${vetTitle(note.vetName)} · ترخيص رقم ${note.licenseNumber}', style: text.bodySmall!.copyWith(color: Palette.body)),
        if (onCorrect != null && !replaced)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onCorrect,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('إصدار تصحيح'),
            ),
          ),
      ]),
    );
  }
}

/// «د. سارة القحطاني», without repeating an existing «د.».
String vetTitle(String fullName) {
  final name = fullName.trim();
  return name.startsWith('د.') || name.startsWith('د ') ? name : 'د. $name';
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Palette.canvas, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(medicine.name, style: text.titleSmall),
        const SizedBox(height: 4),
        Text('${medicine.dose} · ${medicine.frequency} · لمدة ${medicine.duration}', style: text.bodyMedium),
      ]),
    );
  }
}
