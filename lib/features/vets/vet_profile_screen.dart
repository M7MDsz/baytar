import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../booking/booking_screen.dart';
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
            return ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: CircleAvatar(radius: 40, child: Text(v.fullName.characters.first, style: text.headlineMedium))),
              const SizedBox(height: 12),
              Center(child: Text(v.fullName, style: text.headlineSmall)),
              if (v.rating != null)
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, color: Colors.amber),
                    Text(v.rating!.toStringAsFixed(1)),
                  ]),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Row(children: [
                      Icon(Icons.verified, color: Colors.green),
                      SizedBox(width: 8),
                      Text('ترخيص موثّق من بيطار'),
                    ]),
                    const Divider(),
                    InfoRow('رقم الترخيص', v.licenseNumber),
                    InfoRow('صالح حتى', formatDate(v.licenseExpiry)),
                    InfoRow('التخصصات', labelList(specialtyLabels, v.specialties)),
                    InfoRow('الحيوانات', labelList(speciesLabels, v.animalTypes)),
                    InfoRow('اللغات', labelList(languageLabels, v.languages)),
                  ]),
                ),
              ),
              if ((v.bio ?? '').isNotEmpty) ...[const SectionTitle('نبذة'), Text(v.bio!)],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: v.bookable ? () => context.push(bookingPath(v.id, vetName: v.fullName)) : null,
                icon: const Icon(Icons.event_available),
                label: Text(v.bookable ? 'عرض المواعيد والحجز' : 'لا توجد مواعيد متاحة'),
              ),
            ]);
          },
        ),
      );
}
