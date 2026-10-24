import 'package:flutter/material.dart';

const termsOfUse = '''
باستخدامك تطبيق بيطار فإنك توافق على ما يلي:
• بيطار منصة استشارات بيطرية عن بُعد، ولا تغني عن زيارة العيادة في الحالات الطارئة.
• تلتزم بإدخال معلومات صحيحة عن حيوانك وحالته.
• يقدّم الاستشارات أطباء بيطريون تحقق بيطار من تراخيصهم.
• يمكنك إلغاء الموعد أو تغييره قبل موعده بـ 12 ساعة على الأقل.
• لا يجوز استخدام التطبيق لأي غرض مخالف للأنظمة.
''';

/// Required "I accept the terms of use" checkbox (US-29, US-31).
class TermsField extends FormField<bool> {
  TermsField({super.key, required ValueChanged<bool> onChanged})
      : super(
          initialValue: false,
          validator: (v) => v == true ? null : 'يجب الموافقة على شروط الاستخدام',
          builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: field.value,
              onChanged: (v) {
                field.didChange(v);
                onChanged(v ?? false);
              },
              title: Wrap(children: [
                const Text('أوافق على '),
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: field.context,
                    builder: (context) => AlertDialog(
                      title: const Text('شروط الاستخدام'),
                      content: const SingleChildScrollView(child: Text(termsOfUse)),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
                    ),
                  ),
                  child: Text(
                    'شروط الاستخدام',
                    style: TextStyle(
                      color: Theme.of(field.context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ]),
            ),
            if (field.hasError)
              Text(field.errorText!, style: TextStyle(color: Theme.of(field.context).colorScheme.error, fontSize: 12)),
          ]),
        );
}
