import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'outcome_form_screen.dart';

/// US-20. Opened after the veterinarian ends a consultation (US-19) or from the case page.
final outcomeEditorFeature = Feature(
  routes: [
    GoRoute(
      path: '/vet/appointments/:id/outcome',
      builder: (_, s) => OutcomeFormScreen(appointmentId: s.pathParameters['id']!),
    ),
  ],
);
