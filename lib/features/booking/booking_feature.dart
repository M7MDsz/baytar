import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'appointment_detail_screen.dart';
import 'booking_screen.dart';
import 'my_appointments_screen.dart';

/// US-11.
final bookingFeature = Feature(
  tabs: [
    HomeTab(
      roles: {UserRole.owner},
      order: 30,
      label: 'مواعيدي',
      icon: Icons.event_note,
      path: '/appointments',
      builder: (_) => const MyAppointmentsScreen(),
    ),
  ],
  routes: [
    GoRoute(
      path: '/book/:vetId',
      builder: (_, s) => BookingScreen(vetId: s.pathParameters['vetId']!, vetName: s.uri.queryParameters['name']),
    ),
    GoRoute(
      path: '/appointments/:id',
      builder: (_, s) => AppointmentDetailScreen(appointmentId: s.pathParameters['id']!),
    ),
  ],
  roleGuards: {'/book': {UserRole.owner}, '/appointments': {UserRole.owner}},
);
