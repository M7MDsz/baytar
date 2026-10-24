import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'pending_vets_screen.dart';
import 'vet_review_screen.dart';

/// US-32. Anyone who is not an administrator is sent to /forbidden; the database refuses them too.
final adminFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.admin},
      order: 10,
      label: 'التحقق',
      icon: Icons.verified_user_outlined,
      path: '/admin/vets',
      builder: (_) => const PendingVetsScreen(),
    ),
  ],
  routes: [
    GoRoute(path: '/admin/vets/:id', builder: (_, s) => VetReviewScreen(vetId: s.pathParameters['id']!)),
  ],
  roleGuards: {'/admin': {UserRole.admin}},
);
