import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/catalog.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/storage.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import 'pending_vet.dart';
import 'pending_vets_screen.dart';

const _decisionErrors = {
  'reason_required': 'اكتب سبب الرفض.',
  'not_pending': 'تم البت في هذا الطلب مسبقاً.',
  'forbidden': 'هذه الصفحة للمشرفين فقط.',
};

/// US-32: the entered details, the license file, and Approve / Reject (with a written reason).
class VetReviewScreen extends StatefulWidget {
  const VetReviewScreen({super.key, required this.vetId});

  final String vetId;

  @override
  State<VetReviewScreen> createState() => _VetReviewScreenState();
}

class _VetReviewScreenState extends State<VetReviewScreen> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
      if (reason == null) return;
    } else {
      final ok = await confirmDialog(context, title: 'قبول الطبيب', message: 'سيظهر الطبيب للملاك ويمكنه نشر المواعيد.', confirmLabel: 'قبول');
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await db.rpc('decide_vet', params: {'p_vet': widget.vetId, 'p_approve': approve, 'p_reason': reason});
      if (!mounted) return;
      showSnack(context, approve ? 'تم توثيق الطبيب' : 'تم رفض الطلب وإشعار الطبيب');
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, _decisionErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLicense(PendingVet v) async {
    final url = await signedUrl('licenses', v.licensePath);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مراجعة الترخيص')),
        body: AsyncView<PendingVet?>(
          load: () async => (await loadPendingVets()).where((v) => v.id == widget.vetId).firstOrNull,
          builder: (context, v, _) {
            if (v == null) return const EmptyState(icon: Icons.task_alt, message: 'هذا الطلب لم يعد بانتظار التحقق.');
            final isImage = !v.licensePath.toLowerCase().endsWith('.pdf');
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('الاسم', v.fullName),
                    InfoRow('البريد', v.email),
                    InfoRow('الجوال', v.mobile),
                    InfoRow('رقم الترخيص', v.licenseNumber),
                    InfoRow('ينتهي في', formatDate(v.licenseExpiry)),
                    InfoRow('التخصصات', labelList(specialtyLabels, v.specialties)),
                    InfoRow('الحيوانات', labelList(speciesLabels, v.animalTypes)),
                    InfoRow('اللغات', labelList(languageLabels, v.languages)),
                    InfoRow('نبذة', v.bio),
                  ]),
                ),
              ),
              const SectionTitle('ملف الترخيص'),
              if (isImage)
                FutureBuilder<String>(
                  future: signedUrl('licenses', v.licensePath),
                  builder: (context, snap) => snap.hasData ? Image.network(snap.data!) : const LinearProgressIndicator(),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _openLicense(v),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('فتح ملف PDF'),
                ),
              const SizedBox(height: 24),
              BusyButton(busy: _busy, onPressed: () => _decide(approve: true), label: 'قبول وتوثيق'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _decide(approve: false),
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('رفض'),
              ),
            ]);
          },
        ),
      );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: _reason,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(hintText: 'مثال: صورة الترخيص غير واضحة', errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          FilledButton(
            onPressed: () {
              if (_reason.text.trim().isEmpty) {
                setState(() => _error = _decisionErrors['reason_required']);
                return;
              }
              Navigator.pop(context, _reason.text.trim());
            },
            child: const Text('رفض'),
          ),
        ],
      );
}
