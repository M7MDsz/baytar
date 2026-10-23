import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'outcome_view_screen.dart';

/// US-16.
final outcomesFeature = Feature(
  routes: [
    GoRoute(
      path: '/outcomes/:appointmentId',
      builder: (_, s) => OutcomeViewScreen(appointmentId: s.pathParameters['appointmentId']!),
    ),
  ],
  roleGuards: {'/outcomes': {UserRole.owner}},
);
