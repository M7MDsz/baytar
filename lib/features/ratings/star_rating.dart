import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';

/// US-38: five stars to tap. [value] is 0 before a choice.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '${arabicDigits(i)} من ٥',
            iconSize: size,
            padding: const EdgeInsets.all(2),
            onPressed: () => onChanged(i),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(i <= value),
                color: i <= value ? Palette.accent : Palette.lineStrong,
              ),
            ),
          ),
      ]);
}

/// Read-only stars, for a given rating.
class StarRow extends StatelessWidget {
  const StarRow(this.stars, {super.key, this.size = 18});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${arabicDigits(stars)} من ٥ نجوم',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: i <= stars ? Palette.accent : Palette.lineStrong),
        ]),
      );
}
