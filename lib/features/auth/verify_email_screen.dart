import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';

/// US-29: enter the 6-digit code from the email. A code older than 10 minutes is refused; a new one can be sent.
/// [onVerified] lets the veterinarian registration (US-31) finish its own steps right after activation.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.onVerified});

  final String email;
  final Future<void> Function()? onVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _repo = AuthRepository();
  bool _busy = false;
  bool _expired = false;

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _repo.verifySignUpCode(widget.email, _code.text);
      await widget.onVerified?.call();
      // Signed in now; the router opens the start page in Arabic.
    } catch (e) {
      if (!mounted) return;
      setState(() => _expired = true);
      showSnack(context, friendlyError(e, {'expired': 'الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً.'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _repo.resendSignUpCode(widget.email);
      if (mounted) {
        setState(() => _expired = false);
        showSnack(context, 'تم إرسال رمز جديد إلى بريدك');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفعيل الحساب')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Palette.amberSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.surface, width: 4),
                  boxShadow: softShadow,
                ),
                child: const Icon(Icons.mark_email_read_outlined, size: 38, color: Palette.amberDeep),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'أرسلنا رمزاً من 6 أرقام إلى\n${widget.email}\nالرمز صالح لمدة 10 دقائق.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700, color: Palette.ink),
                  decoration: const InputDecoration(labelText: 'رمز التفعيل'),
                  validator: validateOtp,
                ),
                const SizedBox(height: 12),
                BusyButton(busy: _busy, onPressed: _verify, label: 'تفعيل'),
              ]),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _resend, child: Text(_expired ? 'إرسال رمز جديد' : 'لم يصلك الرمز؟ إعادة الإرسال')),
          ]),
        ),
      );
}
