import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'errors.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: error
          ? Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ])
          : Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
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
      ],
    ),
  );
  return result ?? false;
}

/// Friendly empty or error state: a soft brand medallion, a short message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    color: Palette.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.canvas, width: 3),
                  ),
                  child: const Icon(Icons.pets, size: 16, color: Palette.sand),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
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

/// Loads [future] and shows a spinner, an error with retry, or [builder].
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
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            message: friendlyError(snap.error!),
            action: OutlinedButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
          );
        }
        return RefreshIndicator(
          color: Palette.juniper,
          backgroundColor: Palette.surface,
          onRefresh: () async => _reload(),
          child: widget.builder(context, snap.data as T, _reload),
        );
      },
    );
  }
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
    return Padding(
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
      Tone.accent => (Palette.amberSoft, Palette.amberDeep),
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
          border: Border.all(color: Palette.amber.withValues(alpha: 0.35), width: radius > 32 ? 3 : 2),
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
      background: code == 'other' ? Palette.sand : (warm ? Palette.amberSoft : Palette.juniperSoft),
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
        background: gender == 'female' ? Palette.amberSoft : Palette.juniperSoft,
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
    if (icon == null || busy) return FilledButton(onPressed: busy ? null : onPressed, child: child);
    return FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
  }
}
