import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'vet_profile_screen.dart';
import 'vets_screen.dart';

/// US-08, US-09, US-10.
final vetsFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.owner},
      order: 25,
      label: 'الأطباء',
      icon: Icons.medical_services_outlined,
      path: '/vets',
      builder: (_) => const VetsScreen(),
    ),
  ],
  routes: [
    GoRoute(path: '/vets/:id', builder: (_, s) => VetProfileScreen(vetId: s.pathParameters['id']!)),
  ],
  roleGuards: {'/vets': {UserRole.owner}},
);
