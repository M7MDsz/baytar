import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'outcome.dart';
import 'outcomes_repository.dart';
import 'referral_card.dart';

/// US-16: read-only consultation outcome for the owner.
class OutcomeViewScreen extends StatelessWidget {
  const OutcomeViewScreen({super.key, required this.appointmentId});

  final String appointmentId;

  Future<(Outcome?, List<Referral>)> _load() async {
    final repo = OutcomesRepository();
    final outcome = await repo.forAppointment(appointmentId);
    final referrals = outcome == null ? <Referral>[] : await repo.referralsForCase(outcome.caseId);
    return (outcome, referrals);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('نتيجة الاستشارة')),
        body: AsyncView<(Outcome?, List<Referral>)>(
          load: _load,
          builder: (context, data, _) {
            final (o, referrals) = data;
            if (o == null) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.hourglass_empty,
                  message: 'لم يحفظ الطبيب نتيجة هذه الاستشارة بعد.\nستصلك النتيجة هنا عند اعتمادها.',
                ),
              ]);
            }
            final text = Theme.of(context).textTheme;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('الحيوان', o.animalName),
                    InfoRow('رقم الحالة', o.caseNumber),
                    InfoRow('تاريخ الاستشارة', formatDay(o.consultationDate)),
                    InfoRow('الطبيب', o.vetName),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('التشخيص والملاحظات', style: text.titleMedium),
              const SizedBox(height: 6),
              SelectableText(o.findings),
              const SizedBox(height: 16),
              Text('توجيهات الطبيب', style: text.titleMedium),
              const SizedBox(height: 6),
              SelectableText(o.guidance),
              if ((o.ownerNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('ملاحظات لك', style: text.titleMedium),
                const SizedBox(height: 6),
                SelectableText(o.ownerNotes!),
              ],
              for (final r in referrals) ...[const SizedBox(height: 16), ReferralCard(referral: r)],
            ]);
          },
        ),
      );
}
