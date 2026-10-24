import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';

/// US-30: request a reset email, then set a new password with the code from that email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository();
  bool _sent = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (!_sent) {
        await _repo.sendPasswordReset(_email.text);
        setState(() => _sent = true);
        if (mounted) showSnack(context, 'إذا كان البريد مسجلاً فستصلك رسالة إعادة التعيين.');
      } else {
        await _repo.resetPassword(email: _email.text, code: _code.text, newPassword: _password.text);
        if (mounted) showSnack(context, 'تم تغيير كلمة المرور');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, friendlyError(e, {'expired': 'الرمز غير صحيح أو انتهت صلاحيته.'}), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('نسيت كلمة المرور')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            TextFormField(
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: validateEmail,
            ),
            if (_sent) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'الرمز من البريد'),
                validator: validateOtp,
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                validator: validateNewPassword,
              ),
            ],
            const SizedBox(height: 20),
            BusyButton(busy: _busy, onPressed: _submit, label: _sent ? 'تغيير كلمة المرور' : 'إرسال رابط إعادة التعيين'),
          ]),
        ),
      );
}
