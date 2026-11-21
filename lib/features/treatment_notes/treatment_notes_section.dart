import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'treatment_note.dart';
import 'treatment_note_card.dart';
import 'treatment_notes_repository.dart';

/// Path of the form where the veterinarian issues a note (or, with [corrects], a correction).
String treatmentNoteFormPath(String appointmentId, {required String caseId, String? corrects}) =>
    Uri(path: '/vet/appointments/$appointmentId/treatment-note', queryParameters: {
      'case': caseId,
      'corrects': ?corrects,
    }).toString();

/// US-37: the treatment notes of one consultation, oldest first. The owner reads them (US-16, US-23); the
/// veterinarian also issues notes and corrections from here ([caseId] given).
class TreatmentNotesSection extends StatefulWidget {
  const TreatmentNotesSection({super.key, required this.appointmentId, this.caseId});

  final String appointmentId;

  /// Set on the veterinarian's case page: shows "issue a note" and "issue a correction".
  final String? caseId;

  @override
  State<TreatmentNotesSection> createState() => _TreatmentNotesSectionState();
}

class _TreatmentNotesSectionState extends State<TreatmentNotesSection> {
  late Future<List<TreatmentNote>> _notes = TreatmentNotesRepository().forAppointment(widget.appointmentId);

  void _reload() => setState(() => _notes = TreatmentNotesRepository().forAppointment(widget.appointmentId));

  Future<void> _issue({String? corrects}) async {
    final issued = await context.push<bool>(
      treatmentNoteFormPath(widget.appointmentId, caseId: widget.caseId!, corrects: corrects),
    );
    if (issued == true) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TreatmentNote>>(
        future: _notes,
        builder: (context, snap) {
          final vet = widget.caseId != null;
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: NoticeBanner(friendlyError(snap.error!), icon: Icons.cloud_off_rounded, tone: Tone.danger),
            );
          }
          final notes = snap.data ?? const <TreatmentNote>[];
          // The owner sees nothing until there is a note.
          if (!vet && notes.isEmpty) return const SizedBox.shrink();
          final replaced = correctedNoteIds(notes);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('ملاحظات العلاج'),
            for (final n in notes)
              TreatmentNoteCard(
                note: n,
                replaced: replaced.contains(n.id),
                onCorrect: vet ? () => _issue(corrects: n.id) : null,
              ),
            if (vet) ...[
              if (snap.connectionState == ConnectionState.done && notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: NoticeBanner('لم تصدر ملاحظة علاج لهذه الاستشارة بعد.', tone: Tone.neutral),
                ),
              FilledButton.tonalIcon(
                style: tonalButton,
                onPressed: () => _issue(),
                icon: const Icon(Icons.medication_outlined),
                label: const Text('إصدار ملاحظة علاج'),
              ),
            ],
          ]);
        },
      );
}
