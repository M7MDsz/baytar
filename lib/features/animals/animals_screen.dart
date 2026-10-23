import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
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
        appBar: AppBar(title: const Text('حيواناتي')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open('/animals/new'),
          icon: const Icon(Icons.add),
          label: const Text('إضافة حيوان'),
        ),
        body: AsyncView<List<Animal>>(
          key: _listKey,
          load: AnimalsRepository().mine,
          builder: (context, animals, _) => animals.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  EmptyState(icon: Icons.pets, message: 'لم تضف أي حيوان بعد.\nابدأ بإضافة ملف لحيوانك.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: animals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = animals[i];
                    return Card(
                      child: ListTile(
                        leading: AnimalPhoto(path: a.photoPath),
                        title: Text(a.name),
                        subtitle: Text([a.speciesLabel, a.sexLabel, a.ageLabel].where((s) => s.isNotEmpty).join(' · ')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _open('/animals/${a.id}'),
                      ),
                    );
                  },
                ),
        ),
      );
}
