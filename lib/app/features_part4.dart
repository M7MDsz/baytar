import '../features/admin/admin_feature.dart';
import '../features/case_review/case_review_feature.dart';
import '../features/reschedule/reschedule_feature.dart';
import '../features/vet_cases/vet_cases_feature.dart';
import '../features/vet_registration/vet_registration_feature.dart';
import 'feature.dart';

/// Part 4 (Abdulaziz Alajaji): the features this part adds to the app.
final part4Features = <Feature>[
  caseReviewFeature,
  vetRegistrationFeature,
  adminFeature,
  rescheduleFeature,
  vetCasesFeature,
];
