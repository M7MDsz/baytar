import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../booking/booking_screen.dart';
import '../ratings/rating.dart';
import '../ratings/ratings_repository.dart';
import '../ratings/star_rating.dart';
import 'vet_card.dart';
import 'vet_summary.dart';
import 'vets_repository.dart';

/// US-10: credentials, license status, specialties, animal types, languages, rating (when any) and Book.
/// US-38: the average rating with the number of ratings, and owners' comments with their first name only.
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
                          const SizedBox(width: 6),
                          Text('(${ratingCountLabel(v.ratingCount)})', style: text.bodyMedium!.copyWith(color: Palette.muted)),
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
                  if (v.ratingCount > 0) _Reviews(vetId: v.id),
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

/// US-38: owners' comments, newest first, with the owner's first name only. Nothing shows when there are none.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.vetId});

  final String vetId;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<VetReview>>(
        future: RatingsRepository().reviews(vetId),
        builder: (context, snap) {
          final reviews = snap.data ?? const <VetReview>[];
          if (reviews.isEmpty) return const SizedBox.shrink();
          final text = Theme.of(context).textTheme;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('آراء المالكين'),
            for (final r in reviews)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.ownerFirstName, style: text.titleSmall)),
                    StarRow(r.stars, size: 16),
                  ]),
                  const SizedBox(height: 6),
                  Text(r.comment, style: text.bodyMedium),
                  const SizedBox(height: 4),
                  Text(formatDay(r.ratedAt), style: text.bodySmall),
                ]),
              ),
          ]);
        },
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
