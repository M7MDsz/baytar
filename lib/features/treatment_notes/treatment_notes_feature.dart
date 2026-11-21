import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'treatment_note_form_screen.dart';
import 'treatment_notes_section.dart';

/// US-37. The '/vet' prefix is limited to veterinarians by the US-34 feature; the database lets only the
/// consultation's own veterinarian issue a note. The owner reads the notes on the outcome (US-16) and the
/// consultation record (US-23) through a ConsultationSection.
final treatmentNotesFeature = Feature(
  consultationSections: [
    ConsultationSection(order: 10, builder: (_, appointmentId) => TreatmentNotesSection(appointmentId: appointmentId)),
  ],
  routes: [
    GoRoute(
      path: '/vet/appointments/:id/treatment-note',
      builder: (_, s) => TreatmentNoteFormScreen(
        appointmentId: s.pathParameters['id']!,
        caseId: s.uri.queryParameters['case'] ?? '',
        corrects: s.uri.queryParameters['corrects'],
      ),
    ),
  ],
);
