import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';

const _outcomeErrors = {
  'not_responsible_vet': 'فقط الطبيب المسؤول عن الموعد يمكنه اعتماد النتيجة.',
  'consultation_not_started': 'لم تبدأ هذه الاستشارة بعد.',
  'findings_and_guidance_required': 'أدخل التشخيص والتوجيهات قبل الاعتماد.',
  'already_approved': 'تم اعتماد هذه النتيجة مسبقاً ولا يمكن تعديلها.',
};

/// US-20: the veterinarian writes findings and guidance, saves a draft, then approves the final outcome.
class OutcomeFormScreen extends StatefulWidget {
  const OutcomeFormScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<OutcomeFormScreen> createState() => _OutcomeFormScreenState();
}

class _OutcomeFormScreenState extends State<OutcomeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _findings = TextEditingController();
  final _guidance = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _approved = false;
  bool _busy = false;
  bool _final = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await db.from('consultation_outcomes').select().eq('appointment_id', widget.appointmentId).maybeSingle();
      if (row != null) {
        _findings.text = row['findings'] as String;
        _guidance.text = row['guidance'] as String;
        _notes.text = (row['owner_notes'] as String?) ?? '';
        _approved = row['status'] == 'approved';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({required bool approve}) async {
    _final = approve;
    if (!_form.currentState!.validate()) return;
    if (approve) {
      final ok = await confirmDialog(
        context,
        title: 'اعتماد النتيجة',
        message: 'بعد الاعتماد تظهر النتيجة للمالك ولا يمكن تعديلها.',
        confirmLabel: 'اعتماد',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await db.rpc('save_outcome', params: {
        'p_appointment': widget.appointmentId,
        'p_findings': _findings.text,
        'p_guidance': _guidance.text,
        'p_owner_notes': _notes.text,
        'p_approve': approve,
      });
      if (!mounted) return;
      showSnack(context, approve ? 'تم اعتماد نتيجة الاستشارة' : 'تم حفظ المسودة');
      if (approve) context.go('/vet/appointments');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, _outcomeErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _requiredOnFinal(String? v, String field) => _final && (v ?? '').trim().isEmpty ? 'أدخل $field' : null;

  @override
  void dispose() {
    for (final c in [_findings, _guidance, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('توثيق نتيجة الاستشارة')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_approved)
            const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('تم اعتماد هذه النتيجة.'))),
          TextFormField(
            controller: _findings,
            readOnly: _approved,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(labelText: requiredLabel('التشخيص والملاحظات السريرية')),
            validator: (v) => _requiredOnFinal(v, 'التشخيص'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _guidance,
            readOnly: _approved,
            minLines: 3,
            maxLines: 10,
            decoration: InputDecoration(labelText: requiredLabel('التوجيهات للمالك')),
            validator: (v) => _requiredOnFinal(v, 'التوجيهات'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            readOnly: _approved,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'ملاحظات إضافية للمالك'),
          ),
          const SizedBox(height: 24),
          if (!_approved) ...[
            BusyButton(busy: _busy, onPressed: () => _save(approve: true), label: 'اعتماد النتيجة'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : () => _save(approve: false), child: const Text('حفظ كمسودة')),
          ],
        ]),
      ),
    );
  }
}
