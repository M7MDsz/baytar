import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'register_vet_screen.dart';
import 'vet_status_screen.dart';

/// US-31.
final vetRegistrationFeature = Feature(
  publicPaths: ['/register/vet'],
  routes: [
    GoRoute(path: '/register/vet', builder: (_, _) => const RegisterVetScreen()),
    GoRoute(path: '/vet/profile/complete', builder: (_, _) => const RegisterVetScreen(completeOnly: true)),
  ],
  tabs: [
    HomeTab(
      roles: {UserRole.vet},
      order: 70,
      label: 'ملفي',
      icon: Icons.badge_outlined,
      path: '/vet/profile',
      builder: (_) => const VetStatusScreen(),
    ),
  ],
);
