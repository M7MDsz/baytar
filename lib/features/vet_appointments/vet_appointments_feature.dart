import 'package:flutter/material.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'vet_appointments_screen.dart';

/// US-34.
final vetAppointmentsFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.vet},
      order: 10,
      label: 'مواعيدي',
      icon: Icons.event_note,
      path: '/vet/appointments',
      builder: (_) => const VetAppointmentsScreen(),
    ),
  ],
  roleGuards: {'/vet': {UserRole.vet}},
);
