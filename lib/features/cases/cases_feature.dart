import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'case_form_screen.dart';
import 'cases_screen.dart';

/// US-03, US-05, US-06 (and the voice recorder from US-04).
final casesFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.owner},
      order: 20,
      label: 'حالاتي',
      icon: Icons.assignment_outlined,
      path: '/cases',
      builder: (_) => const CasesScreen(),
    ),
  ],
  routes: [
    GoRoute(
      path: '/cases/new',
      builder: (_, s) => CaseFormScreen(initialAnimalId: s.uri.queryParameters['animal']),
    ),
    GoRoute(path: '/cases/:id/edit', builder: (_, s) => CaseFormScreen(caseId: s.pathParameters['id'])),
  ],
  roleGuards: {'/cases': {UserRole.owner}},
);
