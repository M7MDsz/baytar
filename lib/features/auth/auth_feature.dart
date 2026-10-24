import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import '../../core/session.dart';
import 'account_screen.dart';
import 'forgot_password_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'verify_email_screen.dart';

/// US-29, US-30.
final authFeature = Feature(
  publicPaths: ['/sign-in', '/sign-up', '/verify-email', '/forgot-password'],
  routes: [
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
    GoRoute(
      path: '/verify-email',
      builder: (_, s) => VerifyEmailScreen(email: s.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
  ],
  tabs: [
    HomeTab(
      roles: UserRole.values.toSet(),
      order: 90,
      label: 'حسابي',
      icon: Icons.person_outline,
      path: '/account',
      builder: (_) => const AccountScreen(),
    ),
  ],
);
