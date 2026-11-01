import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../animals/animal.dart';
import '../animals/animal_photo.dart';
import '../animals/animals_repository.dart';
import 'consultation_history.dart';
import 'history_repository.dart';

/// US-22 View an Animal's Consultation History: only this animal's consultations, newest first, each with the date,
/// the veterinarian and whether the outcome is approved. Read-only; a row opens the record (US-23).
class AnimalHistoryScreen extends StatelessWidget {
  const AnimalHistoryScreen({super.key, required this.animalId});

  final String animalId;

  Future<(Animal, List<HistoryEntry>)> _load() async {
    final animal = AnimalsRepository().byId(animalId);
    final history = HistoryRepository().forAnimal(animalId);
    return (await animal, await history);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('السجل الطبي')),
        body: AsyncView<(Animal, List<HistoryEntry>)>(
          load: _load,
          builder: (context, data, _) {
            final (animal, entries) = data;
            final text = Theme.of(context).textTheme;
            return ListView(padding: pagePadding(context), children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  AnimalPhoto(path: animal.photoPath, species: animal.species, radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('سجل ${animal.name}', style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(consultationCountLabel(entries.length), style: text.bodyMedium!.copyWith(color: Palette.muted)),
                    ]),
                  ),
                ]),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    message: 'لا توجد استشارات سابقة في سجل ${animal.name}.\n'
                        'بعد كل استشارة ستجد هنا تاريخها والطبيب ونتيجتها.',
                    action: FilledButton.tonalIcon(
                      style: tonalButton,
                      onPressed: () => context.push('/cases/new?animal=${animal.id}'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('حالة جديدة'),
                    ),
                  ),
                )
              else ...[
                const SectionTitle('الاستشارات · الأحدث أولاً'),
                for (var i = 0; i < entries.length; i++)
                  _Reveal(index: i, child: _HistoryRow(animalId: animalId, entry: entries[i])),
              ],
            ]);
          },
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.animalId, required this.entry});

  final String animalId;
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return ListCard(
      onTap: () => context.push(consultationRecordPath(animalId, e.appointmentId), extra: e),
      leading: Hero(tag: consultationHeroTag(e.appointmentId), child: DoctorAvatar(e.vetGender, radius: 26)),
      title: historyDateLabel(e.startsAt),
      subtitle: '${vetDisplayName(e.vetName)} · ${formatTime(e.startsAt)}',
      details: Wrap(spacing: 6, runSpacing: 6, children: [
        StatusPill(
          outcomeStatusLabel(e.outcomeApproved),
          tone: e.outcomeApproved ? Tone.success : Tone.neutral,
          icon: e.outcomeApproved ? Icons.check_circle_rounded : null,
          dot: !e.outcomeApproved,
        ),
        if (e.caseNumber != null) TagChip(e.caseNumber!, icon: Icons.tag_rounded),
      ]),
    );
  }
}

/// Fades and slides a row in, a little after the one before it. Plays once; skipped when animations are off.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final delay = 60 * index.clamp(0, 8);
    final total = delay + 360;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
    );
  }
}
