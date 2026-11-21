import 'package:flutter/material.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'admin_dashboard_screen.dart';

/// US-39. The '/admin' prefix is limited to administrators by the US-32 feature; the database refuses anyone else too.
/// The verification list stays the administrator's start page; the dashboard is the second tab.
final adminDashboardFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.admin},
      order: 20,
      label: 'لوحة المتابعة',
      icon: Icons.insights_outlined,
      path: '/admin/dashboard',
      builder: (_) => const AdminDashboardScreen(),
    ),
  ],
);
