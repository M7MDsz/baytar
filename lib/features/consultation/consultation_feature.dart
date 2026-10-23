import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'consultation_room_screen.dart';

/// US-14: the owner joins from the appointment page with `context.push(consultationPath(id))`.
String consultationPath(String appointmentId) => '/consultation/$appointmentId';

final consultationFeature = Feature(
  routes: [
    GoRoute(
      path: '/consultation/:appointmentId',
      builder: (_, s) => ConsultationRoomScreen(appointmentId: s.pathParameters['appointmentId']!),
    ),
  ],
  roleGuards: {'/consultation': {UserRole.owner}},
);
