import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../outcomes/outcome.dart';
import '../outcomes/outcomes_repository.dart';
import 'animal.dart';
import 'animal_photo.dart';
import 'animals_repository.dart';

/// Animal profile with its consultation history (approved outcomes).
class AnimalDetailScreen extends StatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId});

  final String animalId;

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Key _key = UniqueKey();

  Future<(Animal, List<Outcome>)> _load() async => (
        await AnimalsRepository().byId(widget.animalId),
        await OutcomesRepository().forAnimal(widget.animalId),
      );

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
        body: AsyncView<(Animal, List<Outcome>)>(
          key: _key,
          load: _load,
          builder: (context, data, _) {
            final (a, history) = data;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: AnimalPhoto(path: a.photoPath, radius: 48)),
              const SizedBox(height: 12),
              Center(child: Text(a.name, style: Theme.of(context).textTheme.headlineSmall)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('النوع', a.speciesLabel),
                    InfoRow('السلالة', a.breed),
                    InfoRow('الجنس', a.sexLabel),
                    InfoRow('العمر', a.ageLabel),
                    InfoRow('تاريخ الميلاد', a.birthDate == null ? null : formatDate(a.birthDate!)),
                    InfoRow('الوزن', a.weightKg == null ? null : '${a.weightKg} كجم'),
                    InfoRow('حالات معروفة', a.conditions),
                    InfoRow('الحساسية', a.allergies),
                  ]),
                ),
              ),
              const SectionTitle('سجل الاستشارات'),
              if (history.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد استشارات مكتملة بعد.')),
              for (final o in history)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in_outlined),
                    title: Text(formatDay(o.consultationDate)),
                    subtitle: Text(o.vetName ?? ''),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push('/outcomes/${o.appointmentId}'),
                  ),
                ),
            ]);
          },
        ),
      );
}
