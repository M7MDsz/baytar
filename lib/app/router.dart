import 'package:go_router/go_router.dart';

import '../core/session.dart';
import 'feature.dart';
import 'home_shell.dart';
import 'system_screens.dart';

/// Set once in [BaytarApp]; used by code that navigates without a BuildContext (push notifications).
late final GoRouter appRouter;

GoRouter buildRouter(List<Feature> features) {
  final session = Session.instance;
  final tabs = features.expand((f) => f.tabs).toList()..sort((a, b) => a.order.compareTo(b.order));
  final publicPaths = features.expand((f) => f.publicPaths).toSet();
  final guards = {for (final f in features) ...f.roleGuards};
  final tabPaths = <String>{};

  bool matches(String location, String prefix) => location == prefix || location.startsWith('$prefix/');

  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/forbidden', builder: (_, _) => const ForbiddenScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(tabs: tabs, location: state.matchedLocation, child: child),
        routes: [
          for (final tab in tabs)
            if (tabPaths.add(tab.path)) GoRoute(path: tab.path, builder: (context, _) => tab.builder(context)),
        ],
      ),
      ...features.expand((f) => f.routes),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isPublic = publicPaths.any((p) => matches(location, p));
      if (!session.signedIn) {
        if (isPublic) return null;
        return publicPaths.contains('/sign-in') ? '/sign-in' : '/';
      }
      final profile = session.profile;
      if (profile == null) return location == '/' ? null : '/';
      if (location == '/' || isPublic) return homeFor(profile.role, tabs);
      for (final guard in guards.entries) {
        if (matches(location, guard.key) && !guard.value.contains(profile.role)) return '/forbidden';
      }
      return null;
    },
  );
}

String homeFor(UserRole role, List<HomeTab> tabs) =>
    tabs.where((t) => t.roles.contains(role)).firstOrNull?.path ?? '/forbidden';
