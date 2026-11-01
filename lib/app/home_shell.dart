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
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Palette.line),
            boxShadow: const [
              BoxShadow(color: Color(0x1F0E2A25), blurRadius: 28, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x0D0E2A25), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Row(children: [
            for (var i = 0; i < mine.length; i++)
              Expanded(
                flex: i == selected ? 5 : 3,
                child: _NavItem(
                  tab: mine[i],
                  selected: i == selected,
                  onTap: () => context.go(mine[i].path),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (rest, active) = _tabIcons[tab.icon] ?? (tab.icon, tab.icon);
    final item = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? Palette.juniper : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(selected ? active : rest, size: 24, color: selected ? Colors.white : Palette.muted),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: selected
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 7),
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.white, fontSize: 14),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      // Resting tabs show only an icon, so they get a tooltip with the label.
      child: selected ? item : Tooltip(message: tab.label, child: item),
    );
  }
}
