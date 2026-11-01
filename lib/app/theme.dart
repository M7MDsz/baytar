import 'package:flutter/material.dart';

/// Brand colours from the Baytar logo.
const juniper = Color(0xFF0E2A25);
const sand = Color(0xFFF4EEE2);
const amber = Color(0xFFD9772B);

/// The full palette (chosen by Mohammed: "A2, juniper + emerald").
/// Juniper from the logo carries structure and text, emerald marks the main action on a screen,
/// soft mint tints highlight, and warm off-white surfaces keep the app light and calm.
/// The logo itself keeps its own colours.
abstract final class Palette {
  static const juniper = Color(0xFF0E2A25);
  static const juniperMid = Color(0xFF1C463E);
  static const juniperSoft = Color(0xFFE2F3E8);

  /// Main-action colour: buttons, the add button, the current tab, links.
  static const accent = Color(0xFF15803D);
  static const accentSoft = Color(0xFFDCFCE7);
  static const accentDeep = Color(0xFF166534);

  /// Text and icons on the accent.
  static const onAccent = Color(0xFFFFFFFF);

  /// Text buttons and links.
  static const link = Color(0xFF15803D);
  static const sand = Color(0xFFF4EEE2);

  /// Page background: a lighter, cleaner version of the logo's sand.
  static const canvas = Color(0xFFF8F6F1);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1EEE7);

  static const ink = Color(0xFF0E2A25);
  static const body = Color(0xFF243531);
  static const muted = Color(0xFF5B6A66);

  /// Resting icons and labels in the bottom navigation.
  static const navRest = Color(0xFF6B7280);

  static const line = Color(0xFFE8E3D9);
  static const lineStrong = Color(0xFFD3CCBE);

  static const success = Color(0xFF1D7348);
  static const successSoft = Color(0xFFE2F2E8);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFBE9E7);
}

/// Corner radii used across the app.
abstract final class Radii {
  static const card = 20.0;
  static const field = 14.0;
  static const tile = 14.0;
  static const sheet = 28.0;
}

/// Soft card shadow, tinted with juniper instead of plain black.
const softShadow = [
  BoxShadow(color: Color(0x0F0E2A25), blurRadius: 18, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x080E2A25), blurRadius: 3, offset: Offset(0, 1)),
];

const _font = 'IBMPlexSansArabic';

/// Arabic letters join, so every style keeps letter spacing at zero.
TextTheme _textTheme() {
  TextStyle s(double size, FontWeight weight, double height, [Color color = Palette.ink]) =>
      TextStyle(fontFamily: _font, fontSize: size, fontWeight: weight, height: height, letterSpacing: 0, color: color);
  return TextTheme(
    displaySmall: s(30, FontWeight.w700, 1.3),
    headlineMedium: s(26, FontWeight.w700, 1.3),
    headlineSmall: s(22, FontWeight.w700, 1.35),
    titleLarge: s(19, FontWeight.w700, 1.4),
    titleMedium: s(16, FontWeight.w600, 1.45),
    titleSmall: s(14, FontWeight.w600, 1.45),
    bodyLarge: s(16, FontWeight.w400, 1.6, Palette.body),
    bodyMedium: s(14.5, FontWeight.w400, 1.6, Palette.body),
    bodySmall: s(12.5, FontWeight.w400, 1.5, Palette.muted),
    labelLarge: s(15, FontWeight.w600, 1.3),
    labelMedium: s(13, FontWeight.w500, 1.3),
    labelSmall: s(11.5, FontWeight.w500, 1.3, Palette.muted),
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: juniper).copyWith(
    primary: Palette.juniper,
    onPrimary: Colors.white,
    primaryContainer: Palette.juniperSoft,
    onPrimaryContainer: Palette.juniper,
    secondary: Palette.accent,
    onSecondary: Palette.onAccent,
    secondaryContainer: Palette.accentSoft,
    onSecondaryContainer: Palette.accentDeep,
    error: Palette.danger,
    onError: Colors.white,
    errorContainer: Palette.dangerSoft,
    onErrorContainer: Palette.danger,
    surface: Palette.surface,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.muted,
    surfaceContainerLowest: Palette.surface,
    surfaceContainerLow: Palette.canvas,
    surfaceContainer: const Color(0xFFF4F1EB),
    surfaceContainerHigh: Palette.surfaceMuted,
    surfaceContainerHighest: const Color(0xFFEAE5DB),
    outline: Palette.lineStrong,
    outlineVariant: Palette.line,
    surfaceTint: Colors.transparent,
    inverseSurface: Palette.juniper,
    onInverseSurface: Colors.white,
    inversePrimary: Palette.accent,
  );
  final text = _textTheme();
  final stadium = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());
  RoundedRectangleBorder rounded(double r, [BorderSide side = BorderSide.none]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side);
  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: Palette.canvas,
    canvasColor: Palette.surface,
    dividerColor: Palette.line,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.canvas,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 20,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: Palette.ink, size: 24),
      actionsPadding: const EdgeInsetsDirectional.only(end: 8),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Palette.surface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: rounded(Radii.card, const BorderSide(color: Palette.line)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 12,
      horizontalTitleGap: 14,
      iconColor: Palette.juniper,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodyMedium!.copyWith(color: Palette.muted),
      shape: rounded(Radii.card),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? Palette.surfaceMuted : Palette.surface,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field(Palette.lineStrong),
      enabledBorder: field(Palette.lineStrong),
      disabledBorder: field(Palette.line),
      focusedBorder: field(Palette.juniper, 1.6),
      errorBorder: field(Palette.danger),
      focusedErrorBorder: field(Palette.danger, 1.6),
      labelStyle: text.bodyLarge!.copyWith(color: Palette.muted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => text.bodyLarge!.copyWith(
          color: s.contains(WidgetState.error) ? Palette.danger : Palette.juniper,
          fontWeight: FontWeight.w600,
        ),
      ),
      hintStyle: text.bodyLarge!.copyWith(color: Palette.muted.withValues(alpha: 0.8)),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall!.copyWith(color: Palette.danger),
      counterStyle: text.bodySmall,
      prefixIconColor: Palette.muted,
      suffixIconColor: Palette.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: stadium,
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
        textStyle: WidgetStatePropertyAll(text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
        elevation: const WidgetStatePropertyAll(0),
        iconSize: const WidgetStatePropertyAll(20),
        backgroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? const Color(0xFFE9E4DA) : Palette.accent,
        ),
        foregroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? Palette.muted : Palette.onAccent,
        ),
        overlayColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? Palette.onAccent.withValues(alpha: 0.14) : Palette.onAccent.withValues(alpha: 0.06),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: stadium,
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        iconSize: const WidgetStatePropertyAll(20),
        backgroundColor: const WidgetStatePropertyAll(Palette.surface),
        foregroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? Palette.muted : Palette.juniper,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.disabled) ? Palette.line : Palette.lineStrong, width: 1.2),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: stadium,
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        foregroundColor: const WidgetStatePropertyAll(Palette.link),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: Palette.juniper),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Palette.accent,
      foregroundColor: Palette.onAccent,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: const StadiumBorder(),
      extendedTextStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
      extendedPadding: const EdgeInsetsDirectional.only(start: 18, end: 22),
      extendedSizeConstraints: const BoxConstraints(minHeight: 56),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      showCheckmark: true,
      checkmarkColor: Colors.white,
      color: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.juniper : Palette.surface,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(color: s.contains(WidgetState.selected) ? Palette.juniper : Palette.lineStrong),
      ),
      labelStyle: text.labelLarge!.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Palette.ink,
        ),
      ),
      iconTheme: const IconThemeData(color: Palette.juniper, size: 18),
      deleteIconColor: Palette.muted,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.juniper : Palette.surface,
        ),
        foregroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Palette.ink,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.lineStrong)),
        shape: WidgetStatePropertyAll(rounded(Radii.field)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: rounded(6),
      side: const BorderSide(color: Palette.lineStrong, width: 1.6),
      fillColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.juniper : Palette.surface,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.juniper : Palette.lineStrong,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.juniper : const Color(0xFFD9D3C7),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Palette.accentSoft,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? Palette.juniper : Palette.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(
          fontSize: 11.5,
          color: s.contains(WidgetState.selected) ? Palette.juniper : Palette.muted,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(color: Palette.juniper, borderRadius: BorderRadius.circular(999)),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      labelColor: Colors.white,
      unselectedLabelColor: Palette.muted,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w500),
      splashBorderRadius: BorderRadius.circular(999),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.lineStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(24),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.juniper,
      contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white),
      actionTextColor: Palette.accent,
      shape: rounded(Radii.tile),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(Palette.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide(color: Palette.lineStrong)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      textStyle: WidgetStatePropertyAll(text.bodyLarge!.copyWith(color: Palette.ink)),
      hintStyle: WidgetStatePropertyAll(text.bodyLarge!.copyWith(color: Palette.muted)),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.juniper,
      linearTrackColor: Palette.surfaceMuted,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 6,
      borderRadius: BorderRadius.all(Radius.circular(999)),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: Palette.accent, textColor: Palette.onAccent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Palette.juniper, borderRadius: BorderRadius.circular(8)),
      textStyle: text.labelMedium!.copyWith(color: Colors.white),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Palette.juniper,
      headerForegroundColor: Colors.white,
      shape: rounded(24),
      dayStyle: text.bodyMedium,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Palette.surface,
      shape: rounded(24),
    ),
  );
}
