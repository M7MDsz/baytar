import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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

/// Height of the bar itself: 8 + 56 + 8 padding plus the 1 px border top and bottom.
const _barHeight = 74.0;

/// Spring (stiffness 500, damping 30) for the highlight that slides behind the current tab.
class _Spring extends Curve {
  const _Spring();

  static final _sim = SpringSimulation(const SpringDescription(mass: 1, stiffness: 500, damping: 30), 0, 1, 0);
  static const seconds = 0.5;

  @override
  double transformInternal(double t) => _sim.x(t * seconds);
}

/// Floating, frosted bottom navigation built from the tabs registered for the signed-in user's role.
/// The body scrolls behind it (see pagePadding in widgets.dart for the matching list inset).
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
    final radius = BorderRadius.circular(30);
    // The page scrolls behind the frosted bar. Tell it how much of the bottom the bar covers,
    // in both padding (lists) and viewPadding (floating action buttons).
    final media = MediaQuery.of(context);
    final covered = math.max(media.viewPadding.bottom, 12.0) + _barHeight;
    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(bottom: covered),
          viewPadding: media.viewPadding.copyWith(bottom: covered),
        ),
        child: child,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(color: Color(0x2E2A2118), blurRadius: 30, offset: Offset(0, 10), blurStyle: BlurStyle.outer),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: radius,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: SizedBox(
                  height: 56,
                  child: Stack(children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 500),
                      curve: const _Spring(),
                      alignment: AlignmentDirectional(-1 + 2 * selected / (mine.length - 1), 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / mine.length,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Palette.juniperSoft, Palette.juniperSoft.withValues(alpha: 0.3)],
                              ),
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon above a small label. The current tab's icon is filled with amber under a dark outline;
/// the others are outlined in a soft ink. Shrinks a little while pressed.
class _NavItem extends StatefulWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _press(bool down) => setState(() => _pressed = down);

  Widget _icon() {
    final (rest, active) = _tabIcons[widget.tab.icon] ?? (widget.tab.icon, widget.tab.icon);
    if (!widget.selected) return Icon(rest, size: 24, color: Palette.body.withValues(alpha: 0.8));
    // The paw has no outlined form, so it gets a drawn outline instead of an outlined icon on top.
    if (widget.tab.icon == Icons.pets) {
      return Icon(active, size: 24, color: Palette.accent, shadows: [
        for (final o in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)])
          Shadow(color: Palette.ink, offset: o * 0.9),
      ]);
    }
    return Stack(alignment: Alignment.center, children: [
      Icon(active, size: 24, color: Palette.accent),
      Icon(rest, size: 24, color: Palette.ink),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey(selected), child: _icon())),
            const SizedBox(height: 4),
            Text(
              widget.tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: selected ? Palette.ink : Palette.muted,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
