import 'package:flutter/material.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'notifications_screen.dart';
import 'push_service.dart';

/// US-35.
final notificationsFeature = Feature(
  tabs: [
    HomeTab(
      roles: UserRole.values.toSet(),
      order: 80,
      label: 'الإشعارات',
      icon: Icons.notifications_outlined,
      path: '/notifications',
      builder: (_) => const NotificationsScreen(),
    ),
  ],
  onSignedIn: registerForPush,
);
