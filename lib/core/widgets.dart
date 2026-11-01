import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'errors.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: error
          ? Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ])
          : Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

/// Asks for confirmation in a bottom sheet with a drag handle. Returns true only when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: IconTile(
                destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                tone: destructive ? Tone.danger : Tone.brand,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Palette.muted)),
            const SizedBox(height: 24),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ]),
        ),
      );
    },
  );
  return result ?? false;
}

/// Second-level action next to the main button: a soft juniper filled button.
final ButtonStyle tonalButton = FilledButton.styleFrom(
  backgroundColor: Palette.juniperSoft,
  foregroundColor: Palette.juniper,
);

/// Friendly empty or error state: an illustration (a soft brand medallion by default),
/// a short message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action, this.illustration});

  final IconData icon;
  final String message;
  final Widget? action;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          illustration ??
              SizedBox(
                width: 112,
                height: 104,
                child: Stack(children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(color: Palette.juniperSoft, shape: BoxShape.circle),
                      child: Icon(icon, size: 42, color: Palette.juniper),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 2,
                    end: 4,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Palette.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.canvas, width: 3),
                      ),
                      child: const Icon(Icons.pets, size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(message, textAlign: TextAlign.center, style: text.bodyLarge!.copyWith(color: Palette.muted)),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// A few overlapping species cartoons, used as an empty-state illustration.
class SpeciesCluster extends StatelessWidget {
  const SpeciesCluster(this.species, {super.key, this.radius = 34});

  final List<String> species;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final step = radius * 1.35;
    return SizedBox(
      width: radius * 2 + step * (species.length - 1),
      height: radius * 2 + 8,
      child: Stack(children: [
        for (var i = 0; i < species.length; i++)
          PositionedDirectional(
            start: step * i,
            top: i.isOdd ? 8 : 0,
            child: SpeciesAvatar(species[i], radius: radius),
          ),
      ]),
    );
  }
}

/// Loads [future] and shows a shimmering skeleton, an error with retry, or [builder].
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        final Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = const SkeletonList(key: ValueKey('loading'));
        } else if (snap.hasError) {
          child = EmptyState(
            key: const ValueKey('error'),
            icon: Icons.cloud_off_rounded,
            message: friendlyError(snap.error!),
            action: OutlinedButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
          );
        } else {
          child = RefreshIndicator(
            key: const ValueKey('data'),
            color: Palette.juniper,
            backgroundColor: Palette.surface,
            onRefresh: () async => _reload(),
            child: widget.builder(context, snap.data as T, _reload),
          );
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: child);
      },
    );
  }
}

/// Grey placeholder cards with a light sweeping shimmer, shown while a page loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: Palette.surfaceMuted, borderRadius: BorderRadius.circular(8)),
        );
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          for (var i = 0; i < count; i++)
            AppCard(
              shadow: false,
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Palette.surfaceMuted, shape: BoxShape.circle),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    bar(i.isEven ? 140 : 110, 14),
                    const SizedBox(height: 10),
                    bar(i.isEven ? 200 : 170, 10),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Sweeps a soft highlight across [child] (for skeletons).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0)],
            stops: const [0.35, 0.5, 0.65],
            transform: _Slide(_c.value),
          ).createShader(rect),
          child: child,
        ),
      );
}

class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// White rounded card with a hairline border and a soft juniper-tinted shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.onTap,
    this.color = Palette.surface,
    this.borderColor = Palette.line,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.card);
    final card = Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(color: borderColor),
          boxShadow: shadow ? softShadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
    return onTap == null ? card : PressScale(scale: 0.985, child: card);
  }
}

/// A row in a list: leading badge or avatar, title, details and an optional trailing widget.
/// Tappable rows show a chevron that points forward in right-to-left layouts.
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.details,
    this.trailing,
    this.onTap,
    this.color = Palette.surface,
    this.borderColor = Palette.line,
    this.subtitleMaxLines,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? details;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final end = trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right, color: Palette.muted));
    return AppCard(
      onTap: onTap,
      color: color,
      borderColor: borderColor,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 12, 14),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleMedium),
            if ((subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: text.bodyMedium!.copyWith(color: Palette.muted),
                maxLines: subtitleMaxLines,
                overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
              ),
            ],
            if (details != null) ...[const SizedBox(height: 8), details!],
          ]),
        ),
        if (end != null) ...[const SizedBox(width: 8), end],
      ]),
    );
  }
}

/// Colour families for pills and icon tiles.
enum Tone { brand, accent, success, danger, neutral }

(Color, Color) toneColors(Tone tone) => switch (tone) {
      Tone.brand => (Palette.juniperSoft, Palette.juniper),
      Tone.accent => (Palette.accentSoft, Palette.accentDeep),
      Tone.success => (Palette.successSoft, Palette.success),
      Tone.danger => (Palette.dangerSoft, Palette.danger),
      Tone.neutral => (Palette.surfaceMuted, Palette.muted),
    };

/// Small rounded status label, optionally with an icon or a dot.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = Tone.neutral, this.icon, this.dot = false});

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ] else if (icon != null) ...[
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// Quiet, non-interactive label for a specialty, species or language.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.canvas,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: Palette.muted), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Palette.body)),
        ]),
      );
}

/// Rounded square with a tinted background and an icon, used at the start of list rows.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.brand, this.size = 48});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// Round avatar with the first letter of a person's name (a leading «د.» title is skipped).
class NameAvatar extends StatelessWidget {
  const NameAvatar(this.name, {super.key, this.radius = 28});

  final String name;
  final double radius;

  String get _initial {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w != 'د.' && w != 'د');
    final word = words.isEmpty ? name.trim() : words.first;
    return word.isEmpty ? '' : word.characters.first;
  }

  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.sand,
          border: Border.all(color: Palette.accent.withValues(alpha: 0.35), width: radius > 32 ? 3 : 2),
        ),
        child: Text(
          _initial,
          style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700, color: Palette.juniper, height: 1.2),
        ),
      );
}

/// Round illustration on a soft tinted disc (art lives in assets/avatars, sources in assets/avatars/src).
class _IllustratedAvatar extends StatelessWidget {
  const _IllustratedAvatar({required this.asset, required this.background, required this.radius});

  final String asset;
  final Color background;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: Palette.surface, width: radius > 32 ? 3 : 2),
            boxShadow: const [BoxShadow(color: Color(0x140E2A25), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover, excludeFromSemantics: true)),
        ),
      );
}

/// Cartoon avatar for an animal species code from catalog.dart; unknown codes show a paw.
class SpeciesAvatar extends StatelessWidget {
  const SpeciesAvatar(this.species, {super.key, this.radius = 24});

  final String? species;
  final double radius;

  static const _drawn = {'cat', 'dog', 'bird', 'horse', 'camel', 'sheep_goat', 'cattle', 'other'};

  @override
  Widget build(BuildContext context) {
    final code = _drawn.contains(species) ? species! : 'other';
    final warm = const {'dog', 'horse', 'sheep_goat'}.contains(code);
    return _IllustratedAvatar(
      asset: 'assets/avatars/animal_$code.png',
      background: code == 'other' ? Palette.sand : (warm ? Palette.accentSoft : Palette.juniperSoft),
      radius: radius,
    );
  }
}

/// Cartoon veterinarian: a doctor in a ghutra for male, in a hijab for female, neutral when unknown.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar(this.gender, {super.key, this.radius = 28});

  final String? gender;
  final double radius;

  @override
  Widget build(BuildContext context) => _IllustratedAvatar(
        asset: switch (gender) {
          'male' => 'assets/avatars/doctor_male.png',
          'female' => 'assets/avatars/doctor_female.png',
          _ => 'assets/avatars/doctor_neutral.png',
        },
        background: gender == 'female' ? Palette.accentSoft : Palette.juniperSoft,
        radius: radius,
      );
}

/// Card that lists [InfoRow]s with hairlines between them. Rows without a value are left out.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final rows = children.where((w) => w is! InfoRow || (w.value ?? '').trim().isNotEmpty).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(title!, style: Theme.of(context).textTheme.titleSmall),
          ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(),
          rows[i],
        ],
      ]),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 116, child: Text(label, style: text.bodyMedium!.copyWith(color: Palette.muted))),
        Expanded(child: Text(value!, style: text.bodyMedium!.copyWith(color: Palette.ink, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// A titled white card that groups related form fields or content.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (icon != null) ...[IconTile(icon!, size: 32), const SizedBox(width: 10)],
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Tinted note with an icon, for rules and hints the user should notice.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message, {super.key, this.icon = Icons.info_outline, this.tone = Tone.brand});

  final String message;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.tile)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: tone == Tone.neutral ? Palette.body : fg)),
        ),
      ]),
    );
  }
}

/// Segmented, pill-shaped tabs for an [AppBar.bottom].
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Palette.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.line),
          ),
          child: TabBar(tabs: tabs),
        ),
      );
}

/// Sticky footer for a screen's main action, above the system inset.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.surface,
          border: Border(top: BorderSide(color: Palette.line)),
          boxShadow: [BoxShadow(color: Color(0x0D0E2A25), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

/// Writes a number with Arabic-Indic digits (٠١٢…), matching the dates the app shows.
String arabicDigits(Object n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : digits[d];
  }).join();
}

/// List padding for a page: 16 at the sides and, at the bottom, [bottom] plus the system inset.
EdgeInsets pagePadding(BuildContext context, {double top = 4, double bottom = 24}) =>
    EdgeInsets.fromLTRB(16, top, 16, bottom + MediaQuery.paddingOf(context).bottom);

/// Label with a red star for required form fields.
String requiredLabel(String text) => '$text *';

class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.busy, required this.onPressed, required this.label, this.icon});

  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.juniper))
        : Text(label);
    if (icon == null || busy) return PressScale(child: FilledButton(onPressed: busy ? null : onPressed, child: child));
    return PressScale(child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child));
  }
}

/// Fades a list item in while it rises 12 px, a little after the one before it (first load only).
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, 12 * (1 - _t.value)), child: child),
        ),
      );
}

/// Shrinks its child slightly while a pointer is down on it.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down && !MediaQuery.disableAnimationsOf(context) ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// A mint disc that pops in, then an emerald check that draws itself. Used after a booking or a submitted case.
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 750),
        builder: (context, t, _) => CustomPaint(size: Size.square(size), painter: _CheckPainter(t)),
      );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final disc = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
    canvas.drawCircle(c, size.width / 2 * disc, Paint()..color = Palette.accentSoft);
    final draw = Curves.easeInOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (draw == 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * draw),
      Paint()
        ..color = Palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
