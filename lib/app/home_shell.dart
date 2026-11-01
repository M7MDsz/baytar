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

/// Material 3 "emphasized decelerate".
const _decelerate = Cubic(0.05, 0.7, 0.1, 1);

/// Floating bottom navigation built from the tabs registered for the signed-in user's role.
///
/// Switching tabs plays a light fade-through: the old page is gone at once and the new one fades in
/// while sliding 24 px in from the side of the tapped tab and settling from 98% scale (260 ms),
/// starting together with the indicator. Skipped when the system asks for reduced motion.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.tabs, required this.location, required this.child});

  final List<HomeTab> tabs;
  final String location;
  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final Animation<double> _t = CurvedAnimation(parent: _enter, curve: _decelerate);

  /// +1 when the new tab is after the old one in tab order, -1 when before.
  double _towardsEnd = 1;

  List<HomeTab> get _mine {
    final role = Session.instance.profile?.role;
    return widget.tabs.where((t) => role != null && t.roles.contains(role)).toList();
  }

  int _indexOf(String location, List<HomeTab> mine) {
    final found = mine.indexWhere((t) => location == t.path || location.startsWith('${t.path}/'));
    return found < 0 ? 0 : found;
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    final mine = _mine;
    final from = _indexOf(old.location, mine), to = _indexOf(widget.location, mine);
    if (from == to) return;
    _towardsEnd = to > from ? 1 : -1;
    if (MediaQuery.of(context).disableAnimations) {
      _enter.value = 1;
    } else {
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    if (mine.length < 2) return widget.child;
    final selected = _indexOf(widget.location, mine);
    // Tab order runs from the start side, so "towards the end" is to the left in Arabic.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = 24 * _towardsEnd * (rtl ? -1 : 1);
    return Scaffold(
      body: AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset(dx * (1 - _t.value), 0),
            child: Transform.scale(scale: 0.98 + 0.02 * _t.value, child: child),
          ),
        ),
      ),
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
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
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
