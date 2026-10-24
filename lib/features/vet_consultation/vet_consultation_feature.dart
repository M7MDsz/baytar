import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'vet_consultation_screen.dart';

/// US-19. The '/vet' prefix is limited to veterinarians by the US-34 feature.
final vetConsultationFeature = Feature(
  routes: [
    GoRoute(
      path: '/vet/consultation/:appointmentId',
      builder: (_, s) => VetConsultationScreen(appointmentId: s.pathParameters['appointmentId']!),
    ),
  ],
);
