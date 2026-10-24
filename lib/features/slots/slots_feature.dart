import 'package:flutter/material.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'schedule_screen.dart';

/// US-33.
final slotsFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.vet},
      order: 20,
      label: 'جدولي',
      icon: Icons.calendar_month_outlined,
      path: '/vet/schedule',
      builder: (_) => const ScheduleScreen(),
    ),
  ],
);
