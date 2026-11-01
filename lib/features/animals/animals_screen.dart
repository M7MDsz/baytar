import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'animal.dart';
import 'animal_photo.dart';
import 'animals_repository.dart';

/// Owner start page: "My animals".
class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key});

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  Key _listKey = UniqueKey();

  Future<void> _open(String path) async {
    await context.push(path);
    setState(() => _listKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('حيواناتي'), actions: const [NotificationBell()]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open('/animals/new'),
          icon: const Icon(Icons.add),
          label: const Text('إضافة حيوان'),
        ),
        body: AsyncView<List<Animal>>(
          key: _listKey,
          load: AnimalsRepository().mine,
          builder: (context, animals, _) => animals.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.pets,
                    illustration: const SpeciesCluster(['cat', 'dog', 'camel']),
                    message: 'لم تضف أي حيوان بعد.\nابدأ بإضافة ملف لحيوانك.',
                    action: FilledButton.icon(
                      onPressed: () => _open('/animals/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة حيوان'),
                    ),
                  ),
                ])
              : ListView(
                  padding: pagePadding(context, bottom: 96),
                  children: [
                    for (final (i, a) in animals.indexed)
                      Entrance(
                        index: i,
                        child: ListCard(
                          leading: Hero(
                            tag: 'animal-${a.id}',
                            child: AnimalPhoto(path: a.photoPath, species: a.species, radius: 28),
                          ),
                          title: a.name,
                          subtitle: [a.speciesLabel, a.sexLabel, a.ageLabel].where((s) => s.isNotEmpty).join(' · '),
                          onTap: () => _open('/animals/${a.id}'),
                        ),
                      ),
                  ],
                ),
        ),
      );
}
