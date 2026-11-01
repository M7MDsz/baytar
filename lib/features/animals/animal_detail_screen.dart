import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../history/consultation_history.dart';
import 'animal.dart';
import 'animal_photo.dart';
import 'animals_repository.dart';

/// Animal profile. Its consultation history opens from «السجل الطبي» (US-22).
class AnimalDetailScreen extends StatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Key _key = UniqueKey();

  Future<Animal> _load() => AnimalsRepository().byId(widget.animalId);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملف الحيوان'), actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await context.push<bool>('/animals/${widget.animalId}/edit');
              if (changed == true) setState(() => _key = UniqueKey());
            },
          ),
        ]),
        body: AsyncView<Animal>(
          key: _key,
          load: _load,
          builder: (context, a, _) {
            final text = Theme.of(context).textTheme;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(children: [
                  Hero(tag: 'animal-${a.id}', child: AnimalPhoto(path: a.photoPath, species: a.species, radius: 52)),
                  const SizedBox(height: 12),
                  Text(a.name, style: text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                    for (final t in [a.speciesLabel, a.sexLabel, a.ageLabel].where((s) => s.isNotEmpty)) TagChip(t),
                  ]),
                ]),
              ),
              InfoCard(children: [
                InfoRow('النوع', a.speciesLabel),
                InfoRow('السلالة', a.breed),
                InfoRow('الجنس', a.sexLabel),
                InfoRow('العمر', a.ageLabel),
                InfoRow('تاريخ الميلاد', a.birthDate == null ? null : formatDate(a.birthDate!)),
                InfoRow('الوزن', a.weightKg == null ? null : '${a.weightKg} كجم'),
                InfoRow('حالات معروفة', a.conditions),
                InfoRow('الحساسية', a.allergies),
              ]),
              const SectionTitle('سجل الاستشارات'),
              ListCard(
                leading: const IconTile(Icons.history_rounded),
                title: 'السجل الطبي',
                subtitle: 'استشارات ${a.name} السابقة ونتائجها',
                onTap: () => context.push(animalHistoryPath(a.id)),
              ),
            ]);
          },
        ),
      );
}
