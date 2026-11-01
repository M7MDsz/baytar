import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'animal_history_screen.dart';
import 'consultation_history.dart';
import 'consultation_record_screen.dart';

/// US-22, US-23. Under /animals, so only owners can open them (the animals feature guards that prefix).
final historyFeature = Feature(
  routes: [
    GoRoute(path: '/animals/:id/history', builder: (_, s) => AnimalHistoryScreen(animalId: s.pathParameters['id']!)),
    GoRoute(
      path: '/animals/:id/history/:appointmentId',
      builder: (_, s) => ConsultationRecordScreen(
        appointmentId: s.pathParameters['appointmentId']!,
        preview: s.extra is HistoryEntry ? s.extra! as HistoryEntry : null,
      ),
    ),
  ],
);
