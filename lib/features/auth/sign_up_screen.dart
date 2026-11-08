import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'terms_field.dart';

/// US-29: owner sign-up. The account becomes active after the emailed code is entered, or at once when the server
/// confirms it without a code.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _terms = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final outcome = await AuthRepository().signUp(
        fullName: _name.text,
        email: _email.text,
        mobile: _mobile.text,
        password: _password.text,
        termsAccepted: _terms,
      );
      // Signed in already (no emailed code needed): the router opens the owner's home in Arabic.
      if (outcome == SignUpOutcome.signedIn || !mounted) return;
      context.push('/verify-email?email=${Uri.encodeComponent(_email.text.trim())}');
    } catch (e) {
      if (mounted) showSnack(context, signUpErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _mobile, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: requiredLabel('الاسم الكامل')),
                validator: validateFullName,
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: requiredLabel('البريد الإلكتروني')),
                validator: validateEmail,
              ),
              gap,
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                maxLength: 10,
                decoration: InputDecoration(labelText: requiredLabel('رقم الجوال'), hintText: '05XXXXXXXX'),
                validator: validateMobile,
              ),
              gap,
              TextFormField(
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: requiredLabel('كلمة المرور'),
                  helperText: '8 أحرف على الأقل، حروف وأرقام',
                ),
                validator: validateNewPassword,
              ),
              gap,
              TermsField(onChanged: (v) => _terms = v),
            ]),
          ),
          const SizedBox(height: 20),
          BusyButton(busy: _busy, onPressed: _submit, label: 'إنشاء الحساب'),
        ]),
      ),
    );
  }
}
