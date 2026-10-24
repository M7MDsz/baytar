import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'answer_request_screen.dart';
import 'owner_case_screen.dart';

/// Owner side of US-07 (sent case page), US-18 (answer a request) and US-21 (see the referral).
final caseReviewFeature = Feature(
  routes: [
    GoRoute(path: '/cases/:id', builder: (_, s) => OwnerCaseScreen(caseId: s.pathParameters['id']!)),
    GoRoute(path: '/requests/:id', builder: (_, s) => AnswerRequestScreen(requestId: s.pathParameters['id']!)),
  ],
  roleGuards: {'/requests': {UserRole.owner}},
);
