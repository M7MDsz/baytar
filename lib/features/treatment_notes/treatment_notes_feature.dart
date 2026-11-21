import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'treatment_note_form_screen.dart';

/// US-37. The '/vet' prefix is limited to veterinarians by the US-34 feature; the database lets only the
/// consultation's own veterinarian issue a note.
final treatmentNotesFeature = Feature(
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
