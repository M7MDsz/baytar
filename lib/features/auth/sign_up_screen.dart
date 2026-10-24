import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'terms_field.dart';

/// US-29: owner sign-up. The account becomes active after the emailed code is entered.
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
      await AuthRepository().signUp(
        fullName: _name.text,
        email: _email.text,
        mobile: _mobile.text,
        password: _password.text,
        termsAccepted: _terms,
      );
      if (mounted) context.push('/verify-email?email=${Uri.encodeComponent(_email.text.trim())}');
    } on AccountExists {
      if (mounted) showSnack(context, 'يوجد حساب مسجّل بهذا البريد الإلكتروني', error: true);
    } catch (e) {
      if (mounted) {
        showSnack(context, friendlyError(e, {'already registered': 'يوجد حساب مسجّل بهذا البريد الإلكتروني'}), error: true);
      }
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
        child: ListView(padding: const EdgeInsets.all(20), children: [
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
          const SizedBox(height: 20),
          BusyButton(busy: _busy, onPressed: _submit, label: 'إنشاء الحساب'),
        ]),
      ),
    );
  }
}
