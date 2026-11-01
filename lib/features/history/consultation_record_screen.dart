import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../outcomes/outcome.dart';
import '../outcomes/referral_card.dart';
import 'consultation_history.dart';
import 'history_repository.dart';

/// US-23 Open a Past Consultation Record: the case description, the veterinarian's documented outcome (only once
/// approved) and the referral, if any. Read-only. The header shows straight away from the history row ([preview]),
/// so the doctor avatar flies in from the list while the rest loads.
class ConsultationRecordScreen extends StatefulWidget {
  const ConsultationRecordScreen({super.key, required this.appointmentId, this.preview});

  final String appointmentId;
  final HistoryEntry? preview;

  @override
  State<ConsultationRecordScreen> createState() => _ConsultationRecordScreenState();
}

class _ConsultationRecordScreenState extends State<ConsultationRecordScreen> {
  late Future<(ConsultationRecord, String?)> _future = HistoryRepository().record(widget.appointmentId);

  void _retry() => setState(() => _future = HistoryRepository().record(widget.appointmentId));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سجل الاستشارة')),
        body: FutureBuilder<(ConsultationRecord, String?)>(
          future: _future,
          builder: (context, snap) {
            final record = snap.data?.$1;
            final preview = widget.preview;
            final Widget body;
            if (snap.hasError) {
              body = EmptyState(
                key: const ValueKey('error'),
                icon: Icons.cloud_off_rounded,
                message: friendlyError(snap.error!, historyErrors),
                action: OutlinedButton(onPressed: _retry, child: const Text('إعادة المحاولة')),
              );
            } else if (record == null) {
              body = const Padding(
                key: ValueKey('loading'),
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              body = Column(
                key: const ValueKey('record'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _details(context, record),
              );
            }
            return ListView(padding: pagePadding(context), children: [
              if (record != null || preview != null)
                _Header(
                  appointmentId: widget.appointmentId,
                  vetGender: snap.data?.$2 ?? preview?.vetGender,
                  vetName: record?.vetName ?? preview!.vetName,
                  startsAt: record?.startsAt ?? preview!.startsAt,
                  approved: record?.outcomeApproved ?? preview!.outcomeApproved,
                  animalName: record?.animalName,
                  caseNumber: record?.caseNumber ?? preview?.caseNumber,
                ),
              AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: body),
            ]);
          },
        ),
      );

  List<Widget> _details(BuildContext context, ConsultationRecord r) {
    final text = Theme.of(context).textTheme;
    final description = (r.description ?? '').trim();
    return [
      SectionCard(
        title: 'وصف الحالة',
        icon: Icons.edit_note_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(description.isEmpty ? 'لا يوجد وصف مكتوب.' : description, style: text.bodyLarge),
          if (r.hasVoice) ...[
            const SizedBox(height: 10),
            const TagChip('أُرفق وصف صوتي', icon: Icons.mic_none_rounded),
          ],
        ]),
      ),
      if (r.outcomeApproved) ...[
        SectionCard(
          title: 'التشخيص والملاحظات',
          icon: Icons.medical_information_outlined,
          child: SelectableText(r.findings ?? '', style: text.bodyLarge),
        ),
        SectionCard(
          title: 'توجيهات الطبيب',
          icon: Icons.checklist_rounded,
          child: SelectableText(r.guidance ?? '', style: text.bodyLarge),
        ),
        if ((r.ownerNotes ?? '').trim().isNotEmpty)
          SectionCard(
            title: 'ملاحظات لك',
            icon: Icons.sticky_note_2_outlined,
            child: SelectableText(r.ownerNotes!, style: text.bodyLarge),
          ),
        if (r.approvedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text('اعتمد الطبيب النتيجة يوم ${formatDay(r.approvedAt!)}', style: text.bodySmall),
          ),
      ] else
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: NoticeBanner(
            'لم يعتمد الطبيب نتيجة هذه الاستشارة بعد. ستظهر هنا عند اعتمادها.',
            icon: Icons.hourglass_empty_rounded,
            tone: Tone.neutral,
          ),
        ),
      if (r.hasReferral)
        ReferralCard(
          referral: Referral(
            reason: r.referralReason!,
            instructions: r.referralInstructions ?? '',
            createdAt: r.referredAt ?? r.startsAt,
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appointmentId,
    required this.vetGender,
    required this.vetName,
    required this.startsAt,
    required this.approved,
    this.animalName,
    this.caseNumber,
  });

  final String appointmentId;
  final String? vetGender;
  final String vetName;
  final DateTime startsAt;
  final bool approved;
  final String? animalName;
  final String? caseNumber;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Hero(tag: consultationHeroTag(appointmentId), child: DoctorAvatar(vetGender, radius: 32)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vetDisplayName(vetName), style: text.titleLarge),
            const SizedBox(height: 2),
            Text(formatDayTime(startsAt), style: text.bodyMedium!.copyWith(color: Palette.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusPill(
                outcomeStatusLabel(approved),
                tone: approved ? Tone.success : Tone.neutral,
                icon: approved ? Icons.check_circle_rounded : null,
                dot: !approved,
              ),
              if ((animalName ?? '').isNotEmpty) TagChip(animalName!, icon: Icons.pets),
              if (caseNumber != null) TagChip(caseNumber!, icon: Icons.tag_rounded),
            ]),
          ]),
        ),
      ]),
    );
  }
}
