import '../features/animals/animals_feature.dart';
import '../features/consultation/consultation_feature.dart';
import '../features/outcomes/outcomes_feature.dart';
import '../features/vet_appointments/vet_appointments_feature.dart';
import 'feature.dart';
import 'features_part2.dart';
import 'features_part3.dart';
import 'features_part4.dart';

/// Every feature in the app. Each part registers its own features in features_partN.dart.
final features = <Feature>[
  animalsFeature,
  consultationFeature,
  outcomesFeature,
  vetAppointmentsFeature,
  ...part2Features,
  ...part3Features,
  ...part4Features,
];
