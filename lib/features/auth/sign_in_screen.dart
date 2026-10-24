import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';

/// US-30. After sign-in the router opens the start page for the user's role.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthRepository().signIn(_email.text, _password.text);
    } on SignInRefused catch (e) {
      if (!mounted) return;
      if (e.reason == 'email_not_confirmed') {
        context.push('/verify-email?email=${Uri.encodeComponent(_email.text.trim())}');
      } else {
        setState(() => _error = e.reason == 'locked'
            ? 'تم إيقاف تسجيل الدخول لهذا الحساب مؤقتاً بعد 5 محاولات خاطئة. حاول بعد 15 دقيقة.'
            : 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 32),
              Image.asset('assets/logo/baytar-mark.png', height: 96),
              const SizedBox(height: 12),
              Text('بيطار', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const Text('طبيبك البيطري عن بُعد', textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              BusyButton(busy: _busy, onPressed: _submit, label: 'تسجيل الدخول'),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: () => context.push('/sign-up'), child: const Text('إنشاء حساب مالك حيوان')),
              TextButton(onPressed: () => context.push('/register/vet'), child: const Text('أنا طبيب بيطري، أريد التسجيل')),
            ]),
          ),
        ),
      );
}
