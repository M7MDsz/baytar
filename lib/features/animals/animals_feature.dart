import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'animal_detail_screen.dart';
import 'animal_form_screen.dart';
import 'animals_screen.dart';

/// US-01, US-02.
final animalsFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.owner},
      order: 10,
      label: 'حيواناتي',
      icon: Icons.pets,
      path: '/animals',
      builder: (_) => const AnimalsScreen(),
    ),
  ],
  routes: [
    GoRoute(path: '/animals/new', builder: (_, _) => const AnimalFormScreen()),
    GoRoute(
      path: '/animals/:id/edit',
      builder: (_, s) => AnimalFormScreen(animalId: s.pathParameters['id']),
    ),
    // Declared after '/animals/new' so "new" is never read as an id.
    GoRoute(path: '/animals/:id', builder: (_, s) => AnimalDetailScreen(animalId: s.pathParameters['id']!)),
  ],
  roleGuards: {'/animals': {UserRole.owner}},
);
