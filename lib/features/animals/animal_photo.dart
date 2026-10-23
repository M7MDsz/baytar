import 'package:flutter/material.dart';

import 'animals_repository.dart';

/// Round animal photo loaded through a signed URL, with a paw placeholder.
class AnimalPhoto extends StatelessWidget {
  const AnimalPhoto({super.key, required this.path, this.radius = 24});

  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = CircleAvatar(radius: radius, child: Icon(Icons.pets, size: radius));
    if (path == null) return placeholder;
    return FutureBuilder<String>(
      future: AnimalsRepository().photoUrl(path!),
      builder: (context, snap) => snap.hasData
          ? CircleAvatar(radius: radius, backgroundImage: NetworkImage(snap.data!))
          : placeholder,
    );
  }
}
