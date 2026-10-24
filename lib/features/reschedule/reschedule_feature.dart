import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'reschedule_screen.dart';

/// US-12 (Cancel, US-13, is on the appointment page). '/appointments' is owner-only (US-11 feature).
final rescheduleFeature = Feature(
  routes: [
    GoRoute(
      path: '/appointments/:id/reschedule',
      builder: (_, s) => RescheduleScreen(appointmentId: s.pathParameters['id']!),
    ),
  ],
);
