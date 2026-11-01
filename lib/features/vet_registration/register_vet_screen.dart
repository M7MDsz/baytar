import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/session.dart';
import '../../core/storage.dart';
import '../../core/widgets.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_validators.dart';
import '../auth/terms_field.dart';
import '../auth/verify_email_screen.dart';
import 'vet_application.dart';

/// US-31. [completeOnly] is used by a signed-in veterinarian whose professional details were never saved.
class RegisterVetScreen extends StatefulWidget {
  const RegisterVetScreen({super.key, this.completeOnly = false});

  final bool completeOnly;

  @override
  State<RegisterVetScreen> createState() => _RegisterVetScreenState();
}

class _RegisterVetScreenState extends State<RegisterVetScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _bio = TextEditingController();
  DateTime? _expiry;
  File? _licenseFile;
  final _specialties = <String>{};
  final _animalTypes = <String>{};
  final _languages = <String>{'ar'};
  bool _terms = false;
  bool _busy = false;

  Future<void> _pickLicense() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    final f = files.firstOrNull;
    if (f == null || f.path == null) return;
    final file = File(f.path!);
    final reason = licenseFileRejection(extensionOf(f.path!), await file.length());
    if (!mounted) return;
    if (reason != null) {
      showSnack(context, reason, error: true);
      return;
    }
    setState(() => _licenseFile = file);
  }

  VetApplication _application() => VetApplication(
        licenseNumber: _license.text,
        licenseExpiry: _expiry!,
        licenseFile: _licenseFile!,
        specialties: _specialties.toList(),
        animalTypes: _animalTypes.toList(),
        languages: _languages.toList(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (await VetApplication.licenseNumberTaken(_license.text)) {
        if (mounted) showSnack(context, vetRegistrationErrors['license_taken']!, error: true);
        return;
      }
      final application = _application();
      if (widget.completeOnly) {
        await application.submit();
        await Session.instance.reload();
        if (mounted) context.go('/vet/profile');
        return;
      }
      await AuthRepository().signUp(
        fullName: _name.text,
        email: _email.text,
        mobile: _mobile.text,
        password: _password.text,
        termsAccepted: _terms,
        role: 'vet',
      );
      if (!mounted) return;
      // The email code comes first; the license is saved right after the account is active.
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VerifyEmailScreen(email: _email.text.trim(), onVerified: application.submit),
      ));
    } on AccountExists {
      if (mounted) showSnack(context, 'يوجد حساب مسجّل بهذا البريد الإلكتروني', error: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, vetRegistrationErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(String title, Map<String, String> options, Set<String> selected) => FormField<void>(
        validator: (_) => selected.isEmpty ? 'اختر $title' : null,
        builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 10),
            child: Text(requiredLabel(title), style: Theme.of(context).textTheme.titleSmall),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in options.entries)
              FilterChip(
                label: Text(e.value),
                selected: selected.contains(e.key),
                onSelected: (on) => setState(() => on ? selected.add(e.key) : selected.remove(e.key)),
              ),
          ]),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
            ),
        ]),
      );

  @override
  void dispose() {
    for (final c in [_name, _email, _mobile, _password, _license, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(widget.completeOnly ? 'إكمال بيانات الترخيص' : 'تسجيل طبيب بيطري')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          if (!widget.completeOnly) ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(controller: _name, decoration: InputDecoration(labelText: requiredLabel('الاسم الكامل')), validator: validateFullName),
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
                  decoration: InputDecoration(labelText: requiredLabel('كلمة المرور'), helperText: '8 أحرف على الأقل، حروف وأرقام'),
                  validator: validateNewPassword,
                ),
              ]),
            ),
            const SectionTitle('بيانات الترخيص'),
          ],
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _license,
                decoration: InputDecoration(labelText: requiredLabel('رقم الترخيص المهني')),
                validator: (v) => (v ?? '').trim().isEmpty ? 'أدخل رقم الترخيص' : null,
              ),
              gap,
              FormField<void>(
                validator: (_) {
                  if (_expiry == null) return 'اختر تاريخ انتهاء الترخيص';
                  if (!_expiry!.isAfter(DateTime(now.year, now.month, now.day))) return vetRegistrationErrors['license_expiry_not_future'];
                  return null;
                },
                builder: (field) => InputDecorator(
                  decoration: InputDecoration(labelText: requiredLabel('تاريخ انتهاء الترخيص'), errorText: field.errorText),
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _expiry ?? now.add(const Duration(days: 365)),
                        firstDate: now,
                        lastDate: DateTime(now.year + 10),
                      );
                      if (d != null) setState(() => _expiry = d);
                    },
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          _expiry == null ? 'اختر التاريخ' : formatDate(_expiry!),
                          style: TextStyle(color: _expiry == null ? Palette.muted : Palette.ink),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Palette.muted),
                    ]),
                  ),
                ),
              ),
              gap,
              FormField<void>(
                validator: (_) => _licenseFile == null ? 'أرفق صورة الترخيص' : null,
                builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  OutlinedButton.icon(
                    onPressed: _pickLicense,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
                      backgroundColor: _licenseFile == null ? Palette.canvas : Palette.successSoft,
                      foregroundColor: _licenseFile == null ? Palette.juniper : Palette.success,
                      side: BorderSide(
                        color: field.hasError
                            ? Theme.of(context).colorScheme.error
                            : (_licenseFile == null ? Palette.lineStrong : Palette.success),
                      ),
                    ),
                    icon: Icon(_licenseFile == null ? Icons.upload_file : Icons.check_circle),
                    label: Text(_licenseFile == null ? 'إرفاق ملف الترخيص (PDF أو صورة، 10 م.ب)' : 'تم إرفاق الترخيص · تغيير'),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
                    ),
                ]),
              ),
              _chips('التخصصات', specialtyLabels, _specialties),
              _chips('الحيوانات التي تعالجها', speciesLabels, _animalTypes),
              _chips('اللغات', languageLabels, _languages),
              gap,
              TextFormField(controller: _bio, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'نبذة عنك (اختياري)')),
              if (!widget.completeOnly) ...[gap, TermsField(onChanged: (v) => _terms = v)],
            ]),
          ),
          const SizedBox(height: 20),
          BusyButton(busy: _busy, onPressed: _submit, label: widget.completeOnly ? 'إرسال للتحقق' : 'تسجيل'),
          const SizedBox(height: 14),
          const NoticeBanner(
            'بعد التسجيل تكون حالة حسابك «بانتظار التحقق» حتى يراجع المشرف ترخيصك.',
            icon: Icons.hourglass_top,
            tone: Tone.accent,
          ),
        ]),
      ),
    );
  }
}
