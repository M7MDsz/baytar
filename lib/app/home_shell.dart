import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import 'feature.dart';
import 'theme.dart';

/// Bottom navigation built from the tabs registered for the signed-in user's role.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.tabs, required this.location, required this.child});

  final List<HomeTab> tabs;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = Session.instance.profile?.role;
    final mine = tabs.where((t) => role != null && t.roles.contains(role)).toList();
    if (mine.length < 2) return child;
    final selected = mine.indexWhere((t) => location == t.path || location.startsWith('${t.path}/'));
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.surface,
          border: Border(top: BorderSide(color: Palette.line)),
          boxShadow: [BoxShadow(color: Color(0x0F0E2A25), blurRadius: 20, offset: Offset(0, -6))],
        ),
        child: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: (i) => context.go(mine[i].path),
          destinations: [
            for (final t in mine) NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}
