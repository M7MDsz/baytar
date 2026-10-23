import '../features/animals/animals_feature.dart';
import '../features/consultation/consultation_feature.dart';
import '../features/outcomes/outcomes_feature.dart';
import '../features/vet_appointments/vet_appointments_feature.dart';
import 'feature.dart';

/// Every feature in the app. When you add a feature folder, register it here.
final features = <Feature>[
  animalsFeature,
  consultationFeature,
  outcomesFeature,
  vetAppointmentsFeature,
];
