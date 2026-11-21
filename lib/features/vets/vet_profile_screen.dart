import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../booking/booking_screen.dart';
import 'vet_card.dart';
import 'vet_summary.dart';
import 'vets_repository.dart';

/// US-10: credentials, license status, specialties, animal types, languages, rating (when any) and Book.
class VetProfileScreen extends StatelessWidget {
  const VetProfileScreen({super.key, required this.vetId});

  final String vetId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملف الطبيب')),
        body: AsyncView<VetProfile?>(
          load: () => VetsRepository().profile(vetId),
          builder: (context, v, _) {
            if (v == null) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyState(icon: Icons.person_off_outlined, message: 'هذا الطبيب غير متاح حالياً.'),
              ]);
            }
            final text = Theme.of(context).textTheme;
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  AppCard(
                    shadow: false,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(children: [
                      Hero(tag: vetAvatarTag(v.id), child: DoctorAvatar(v.gender, radius: 52)),
                      const SizedBox(height: 14),
                      VerifiedName(v.fullName, style: text.headlineSmall, center: true),
                      const SizedBox(height: 2),
                      Text(
                        labelList(specialtyLabels, v.specialties),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium!.copyWith(color: Palette.muted),
                      ),
                      if (v.rating != null) ...[
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: Palette.accent, size: 22),
                          const SizedBox(width: 4),
                          Text(v.rating!.toStringAsFixed(1), style: text.titleMedium!.copyWith(color: Palette.accentDeep)),
                        ]),
                      ],
                      const SizedBox(height: 14),
                      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                        const StatusPill('ترخيص موثّق من بيطار', tone: Tone.success, icon: Icons.verified),
                        NextSlotChip(v.nextAvailable),
                      ]),
                    ]),
                  ),
                  InfoCard(children: [
                    InfoRow('رقم الترخيص', v.licenseNumber),
                    InfoRow('صالح حتى', formatDate(v.licenseExpiry)),
                  ]),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _ChipGroup('التخصصات', [for (final c in v.specialties) label(specialtyLabels, c)]),
                      const SizedBox(height: 16),
                      _ChipGroup('الحيوانات', [for (final c in v.animalTypes) label(speciesLabels, c)]),
                      const SizedBox(height: 16),
                      _ChipGroup('اللغات', [for (final c in v.languages) label(languageLabels, c)]),
                    ]),
                  ),
                  if ((v.bio ?? '').isNotEmpty) ...[
                    const SectionTitle('نبذة'),
                    AppCard(child: Text(v.bio!, style: text.bodyLarge)),
                  ],
                ]),
              ),
              BottomActionBar(children: [
                FilledButton.icon(
                  onPressed: v.bookable ? () => context.push(bookingPath(v.id, vetName: v.fullName)) : null,
                  icon: const Icon(Icons.event_available),
                  label: Text(v.bookable ? 'عرض المواعيد والحجز' : 'لا توجد مواعيد متاحة'),
                ),
              ]),
            ]);
          },
        ),
      );
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup(this.title, this.labels);

  final String title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Palette.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final l in labels) TagChip(l)]),
      ]);
}
