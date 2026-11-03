import 'dart:math';

import 'package:baytar/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// QA M-6: the edge of a control needs 3:1 against what is around it (WCAG 2.2, 1.4.11).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('control borders reach 3:1 on the white field and on the page', () {
    expect(contrast(Palette.lineStrong, Palette.surface), greaterThanOrEqualTo(3));
    expect(contrast(Palette.lineStrong, Palette.canvas), greaterThanOrEqualTo(3));
  });

  test('text fields and outlined buttons use that border', () {
    final theme = buildTheme();
    final field = theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(field.borderSide.color, Palette.lineStrong);
    final side = theme.outlinedButtonTheme.style!.side!.resolve(<WidgetState>{})!;
    expect(side.color, Palette.lineStrong);
  });
}
