import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'referral_screen.dart';
import 'vet_case_screen.dart';

/// US-17, US-18 (veterinarian side), US-21.
final vetCasesFeature = Feature(
  routes: [
    GoRoute(path: '/vet/cases/:id', builder: (_, s) => VetCaseScreen(caseId: s.pathParameters['id']!)),
    GoRoute(path: '/vet/cases/:id/referral', builder: (_, s) => ReferralScreen(caseId: s.pathParameters['id']!)),
  ],
);
