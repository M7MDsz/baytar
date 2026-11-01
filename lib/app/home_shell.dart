import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import 'feature.dart';
import 'theme.dart';

/// Outlined icon for a resting tab and filled icon for the current one, keyed by the icon a feature registers.
final _tabIcons = <IconData, (IconData, IconData)>{
  Icons.pets: (Icons.pets_outlined, Icons.pets),
  Icons.assignment_outlined: (Icons.assignment_outlined, Icons.assignment),
  Icons.medical_services_outlined: (Icons.medical_services_outlined, Icons.medical_services),
  Icons.event_note: (Icons.event_note_outlined, Icons.event_note),
  Icons.person_outline: (Icons.person_outline, Icons.person),
  Icons.calendar_month_outlined: (Icons.calendar_month_outlined, Icons.calendar_month),
  Icons.badge_outlined: (Icons.badge_outlined, Icons.badge),
  Icons.verified_user_outlined: (Icons.verified_user_outlined, Icons.verified_user),
};

/// Floating bottom navigation built from the tabs registered for the signed-in user's role.
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
    final found = mine.indexWhere((t) => location == t.path || location.startsWith('${t.path}/'));
    final selected = found < 0 ? 0 : found;
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Palette.line),
            boxShadow: const [
              BoxShadow(color: Color(0x1F0E2A25), blurRadius: 28, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x0D0E2A25), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Stack(children: [
            // A short emerald bar just inside the top edge, above the current tab, sliding between tabs.
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: AlignmentDirectional(-1 + 2 * selected / (mine.length - 1), -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / mine.length,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 20,
                      height: 3,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < mine.length; i++)
                Expanded(
                  child: _NavItem(tab: mine[i], selected: i == selected, onTap: () => context.go(mine[i].path)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Icon above a small label: filled emerald with a semi-bold emerald label for the current tab,
/// outlined grey with a regular grey label for the others.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (rest, active) = _tabIcons[tab.icon] ?? (tab.icon, tab.icon);
    final color = selected ? Palette.accent : Palette.navRest;
    final Widget icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(selected ? active : rest, key: ValueKey(selected), size: 24, color: color),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: icon,
          ),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  fontSize: 11.5,
                  height: 1.2,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
            child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
