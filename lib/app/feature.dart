import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';

/// A section a part adds to one consultation's owner pages: the outcome (US-16) and the past consultation record
/// (US-23). Sections show in [order] under the page's own content; each loads its own data and shows nothing when it
/// has nothing to show. Sprint 3: treatment notes (US-37) and the rating (US-38).
class ConsultationSection {
  const ConsultationSection({required this.order, required this.builder});

  final int order;
  final Widget Function(BuildContext context, String appointmentId) builder;
}

/// A bottom-navigation tab. The first tab (lowest [order]) for a role is that role's start page.
class HomeTab {
  const HomeTab({
    required this.roles,
    required this.order,
    required this.label,
    required this.icon,
    required this.path,
    required this.builder,
  });

  final Set<UserRole> roles;
  final int order;
  final String label;
  final IconData icon;
  final String path;
  final WidgetBuilder builder;
}

/// One slice of the app (usually one or two user stories). Registered in `features.dart`.
class Feature {
  const Feature({
    this.routes = const [],
    this.tabs = const [],
    this.publicPaths = const [],
    this.roleGuards = const {},
    this.onSignedIn,
    this.consultationSections = const [],
  });

  /// Full-screen pages opened from tabs with `context.push`.
  final List<RouteBase> routes;
  final List<HomeTab> tabs;

  /// Paths that can be opened without signing in (sign-in, sign-up, ...).
  final List<String> publicPaths;

  /// Path prefix -> roles allowed to open it. Anyone else is sent to /forbidden.
  final Map<String, Set<UserRole>> roleGuards;

  final SignedInHook? onSignedIn;

  /// Sections for the owner's outcome and consultation record pages.
  final List<ConsultationSection> consultationSections;
}
