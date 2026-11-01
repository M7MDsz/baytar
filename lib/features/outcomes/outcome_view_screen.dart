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
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              InfoCard(children: [
                InfoRow('الحيوان', o.animalName),
                InfoRow('رقم الحالة', o.caseNumber),
                InfoRow('تاريخ الاستشارة', formatDay(o.consultationDate)),
                InfoRow('الطبيب', o.vetName),
              ]),
              SectionCard(
                title: 'التشخيص والملاحظات',
                icon: Icons.medical_information_outlined,
                child: SelectableText(o.findings, style: text.bodyLarge),
              ),
              SectionCard(
                title: 'توجيهات الطبيب',
                icon: Icons.checklist_rounded,
                child: SelectableText(o.guidance, style: text.bodyLarge),
              ),
              if ((o.ownerNotes ?? '').isNotEmpty)
                SectionCard(
                  title: 'ملاحظات لك',
                  icon: Icons.sticky_note_2_outlined,
                  child: SelectableText(o.ownerNotes!, style: text.bodyLarge),
                ),
              for (final r in referrals) ReferralCard(referral: r),
            ]);
          },
        ),
      );
}
