import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../animals/animal.dart';
import '../case_review/info_request.dart';
import '../case_review/info_request_card.dart';
import '../case_review/media_gallery.dart';
import '../cases/case_record.dart';
import '../consultation/join_window.dart';
import '../outcomes/outcome.dart';
import '../outcomes/referral_card.dart';
import '../vet_appointments/vet_appointments_screen.dart';
import '../vet_consultation/vet_consultation_screen.dart';
import '../voice/voice_note.dart';
import '../voice/voice_player.dart';

class _VetCase {
  _VetCase(this.record, this.animal, this.requests, this.referrals, this.appointment);

  final CaseRecord record;
  final Animal animal;
  final List<InfoRequest> requests;
  final List<Referral> referrals;
  final Map<String, dynamic>? appointment;
}

/// US-17: an assigned case with the animal, the owner's text or voice description and every attachment.
/// From here the veterinarian can request information (US-18) or refer the case (US-21).
class VetCaseScreen extends StatefulWidget {
  const VetCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<VetCaseScreen> createState() => _VetCaseScreenState();
}

class _VetCaseScreenState extends State<VetCaseScreen> {
  Key _key = UniqueKey();

  void _refresh() => setState(() => _key = UniqueKey());

  /// Null when the case is not assigned to this veterinarian (row level security returns nothing).
  Future<_VetCase?> _load() async {
    final row = await db.from('cases').select('*, case_media(*)').eq('id', widget.caseId).maybeSingle();
    if (row == null) return null;
    final record = CaseRecord.fromMap(row);
    final animal = Animal.fromMap(await db.from('animals').select().eq('id', record.animalId).single());
    final requests = await db.from('info_requests').select().eq('case_id', widget.caseId).order('created_at');
    final referrals = await db.from('referrals').select().eq('case_id', widget.caseId).order('created_at');
    final appointment = await db
        .from('appointments')
        .select('id, starts_at, status, started_at')
        .eq('case_id', widget.caseId)
        .eq('vet_id', currentUserId!)
        .neq('status', 'cancelled')
        .order('starts_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return _VetCase(
      record,
      animal,
      requests.map(InfoRequest.fromMap).toList(),
      referrals.map(Referral.fromMap).toList(),
      appointment,
    );
  }

  Future<void> _requestInfo() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RequestInfoSheet(caseId: widget.caseId),
    );
    if (sent == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الحالة')),
        body: AsyncView<_VetCase?>(
          key: _key,
          load: _load,
          builder: (context, data, _) {
            if (data == null) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyState(icon: Icons.lock_outline, message: 'لا يمكنك فتح هذه الحالة لأنها غير مسندة إليك.'),
              ]);
            }
            final c = data.record, a = data.animal, appt = data.appointment;
            final startsAt = appt == null ? null : parseTs(appt['starts_at']);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${a.name} · ${a.speciesLabel}', style: Theme.of(context).textTheme.headlineSmall),
              if (c.caseNumber != null) Text(c.caseNumber!),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('السلالة', a.breed),
                    InfoRow('الجنس', a.sexLabel),
                    InfoRow('العمر', a.ageLabel),
                    InfoRow('الوزن', a.weightKg == null ? null : '${a.weightKg} كجم'),
                    InfoRow('حالات معروفة', a.conditions),
                    InfoRow('الحساسية', a.allergies),
                    if (startsAt != null) InfoRow('الموعد', formatDayTime(startsAt)),
                  ]),
                ),
              ),
              const SectionTitle('وصف المالك'),
              Text((c.description ?? '').isEmpty ? 'لا يوجد وصف مكتوب.' : c.description!),
              if (c.voicePath != null) ...[const SizedBox(height: 12), VoicePlayer(note: VoiceNote.remote(c.voicePath!))],
              const SectionTitle('المرفقات'),
              MediaGallery(items: c.media),
              for (final r in data.referrals) ReferralCard(referral: r),
              if (data.requests.isNotEmpty) const SectionTitle('طلبات المعلومات'),
              for (final r in data.requests) InfoRequestCard(request: r),
              const SizedBox(height: 24),
              if (appt != null && startsAt != null && appt['status'] == 'booked' && canJoinNow(startsAt, UserRole.vet))
                FilledButton.icon(
                  onPressed: () => context.push(vetConsultationPath(appt['id'] as String)),
                  icon: const Icon(Icons.video_call),
                  label: const Text('الانضمام إلى الاستشارة'),
                ),
              if (appt != null && appt['started_at'] != null)
                OutlinedButton.icon(
                  onPressed: () => context.push(outcomeFormPath(appt['id'] as String)),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('توثيق نتيجة الاستشارة'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _requestInfo, icon: const Icon(Icons.help_outline), label: const Text('طلب معلومات إضافية')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final saved = await context.push<bool>('/vet/cases/${widget.caseId}/referral');
                  if (saved == true) _refresh();
                },
                icon: const Icon(Icons.local_hospital_outlined),
                label: const Text('يحتاج زيارة عيادة (إحالة)'),
              ),
            ]);
          },
        ),
      );
}

class _RequestInfoSheet extends StatefulWidget {
  const _RequestInfoSheet({required this.caseId});

  final String caseId;

  @override
  State<_RequestInfoSheet> createState() => _RequestInfoSheetState();
}

class _RequestInfoSheetState extends State<_RequestInfoSheet> {
  final _message = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      showSnack(context, 'اكتب ما تحتاجه من المالك', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await db.rpc('request_info', params: {'p_case': widget.caseId, 'p_message': _message.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('طلب معلومات من المالك', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'مثال: أرسل صورة واضحة للجرح من قريب'),
          ),
          const SizedBox(height: 16),
          BusyButton(busy: _busy, onPressed: _send, label: 'إرسال الطلب'),
        ]),
      );
}
