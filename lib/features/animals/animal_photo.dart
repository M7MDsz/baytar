import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';
import 'animals_repository.dart';

/// Round animal photo loaded through a signed URL. Without a photo (or while it loads)
/// the cartoon for the animal's [species] is shown.
class AnimalPhoto extends StatelessWidget {
  const AnimalPhoto({super.key, required this.path, this.radius = 24, this.species});

  final String? path;
  final double radius;
  final String? species;

  @override
  Widget build(BuildContext context) {
    final placeholder = SpeciesAvatar(species, radius: radius);
    if (path == null) return placeholder;
    return FutureBuilder<String>(
      future: AnimalsRepository().photoUrl(path!),
      builder: (context, snap) => snap.hasData
          ? Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.sand,
                border: Border.all(color: Palette.surface, width: radius > 32 ? 3 : 2),
                boxShadow: const [BoxShadow(color: Color(0x140E2A25), blurRadius: 6, offset: Offset(0, 2))],
                image: DecorationImage(image: NetworkImage(snap.data!), fit: BoxFit.cover),
              ),
            )
          : placeholder,
    );
  }
}
