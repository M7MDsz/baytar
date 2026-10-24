import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../cases/case_record.dart';
import '../cases/cases_repository.dart';
import '../outcomes/outcome.dart';
import '../outcomes/outcomes_repository.dart';
import '../outcomes/referral_card.dart';
import '../voice/voice_note.dart';
import '../voice/voice_player.dart';
import 'info_request.dart';
import 'info_request_card.dart';
import 'media_gallery.dart';

/// Owner's view of a sent case (US-07), with the veterinarian's information requests (US-18)
/// and in-person referral instructions (US-21).
class OwnerCaseScreen extends StatefulWidget {
  const OwnerCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<OwnerCaseScreen> createState() => _OwnerCaseScreenState();
}

class _OwnerCaseScreenState extends State<OwnerCaseScreen> {
  Key _key = UniqueKey();

  Future<(CaseRecord, List<InfoRequest>, List<Referral>)> _load() async {
    final c = await CasesRepository().byId(widget.caseId);
    final requests = await db.from('info_requests').select().eq('case_id', widget.caseId).order('created_at');
    final referrals = await OutcomesRepository().referralsForCase(widget.caseId);
    return (c, requests.map(InfoRequest.fromMap).toList(), referrals);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحالة')),
        body: AsyncView<(CaseRecord, List<InfoRequest>, List<Referral>)>(
          key: _key,
          load: _load,
          builder: (context, data, _) {
            final (c, requests, referrals) = data;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('رقم الحالة', c.caseNumber),
                    InfoRow('الحيوان', c.animalName),
                    InfoRow('أُرسلت', c.submittedAt == null ? null : formatDayTime(c.submittedAt!)),
                  ]),
                ),
              ),
              for (final r in referrals) ReferralCard(referral: r),
              for (final r in requests)
                InfoRequestCard(
                  request: r,
                  action: r.isOpen
                      ? Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () async {
                              await context.push('/requests/${r.id}');
                              setState(() => _key = UniqueKey());
                            },
                            child: const Text('الرد'),
                          ),
                        )
                      : null,
                ),
              const SectionTitle('الوصف'),
              Text((c.description ?? '').isEmpty ? 'لا يوجد وصف مكتوب.' : c.description!),
              if (c.voicePath != null) ...[const SizedBox(height: 12), VoicePlayer(note: VoiceNote.remote(c.voicePath!))],
              const SectionTitle('المرفقات'),
              MediaGallery(items: c.media),
            ]);
          },
        ),
      );
}
