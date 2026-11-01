import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
        // Light status bar icons over the juniper header.
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Form(
            key: _form,
            child: ListView(padding: EdgeInsets.zero, children: [
              const _Hero(),
              Transform.translate(
                offset: const Offset(0, -44),
                child: Entrance(
                  index: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidden,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
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
                              child: NoticeBanner(_error!, tone: Tone.danger, icon: Icons.error_outline),
                            ),
                          BusyButton(busy: _busy, onPressed: _submit, label: 'تسجيل الدخول'),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/sign-up'),
                        icon: const Icon(Icons.pets),
                        label: const Text('إنشاء حساب مالك حيوان'),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => context.push('/register/vet'),
                        icon: const Icon(Icons.medical_services_outlined, size: 20),
                        label: const Text('أنا طبيب بيطري، أريد التسجيل'),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Juniper header with the logo on a white medallion ringed in emerald.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Palette.juniperMid, Palette.juniper],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 76),
          child: Column(children: [
            // The logo settles in with a soft scale and fade, then the name and the form follow.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
              ),
              child: Container(
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.accent, width: 3),
                ),
                child: Image.asset('assets/logo/baytar-mark.png'),
              ),
            ),
            const SizedBox(height: 16),
            Entrance(
              index: 2,
              child: Column(children: [
                Text('بيطار', style: text.displaySmall!.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text('طبيبك البيطري عن بُعد', style: text.bodyLarge!.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
