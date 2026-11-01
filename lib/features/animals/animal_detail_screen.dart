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
              if (history.isEmpty)
                const NoticeBanner('لا توجد استشارات مكتملة بعد.', icon: Icons.history, tone: Tone.neutral),
              for (final o in history)
                ListCard(
                  leading: const IconTile(Icons.assignment_turned_in_outlined, tone: Tone.success),
                  title: formatDay(o.consultationDate),
                  subtitle: o.vetName ?? '',
                  onTap: () => context.push('/outcomes/${o.appointmentId}'),
                ),
            ]);
          },
        ),
      );
}
