import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';

/// US-21: refer the case for in-person care with a reason and instructions for the owner.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _instructions = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await db.rpc('create_referral', params: {
        'p_case': widget.caseId,
        'p_reason': _reason.text,
        'p_instructions': _instructions.text,
      });
      if (!mounted) return;
      showSnack(context, 'تم حفظ الإحالة وإشعار المالك');
      context.pop(true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إحالة لزيارة عيادة')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _reason,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: requiredLabel('سبب الإحالة')),
              validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل سبب الإحالة' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instructions,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: requiredLabel('تعليمات للمالك')),
              validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل التعليمات' : null,
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _save, label: 'حفظ الإحالة'),
          ]),
        ),
      );
}
