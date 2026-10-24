/// Sign-up and sign-in rules (US-29, US-30). Each returns an Arabic message, or null when valid.
library;

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
final _mobile = RegExp(r'^05\d{8}$');

String? validateFullName(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'أدخل الاسم الكامل';
  if (t.length < 3) return 'الاسم قصير جداً';
  return null;
}

String? validateEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'أدخل البريد الإلكتروني';
  if (!_email.hasMatch(t)) return 'صيغة البريد الإلكتروني غير صحيحة';
  return null;
}

/// Saudi mobile: 10 digits starting with 05.
String? validateMobile(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'أدخل رقم الجوال';
  if (!_mobile.hasMatch(t)) return 'رقم الجوال يجب أن يكون 10 أرقام ويبدأ بـ 05';
  return null;
}

/// At least 8 characters with both letters and numbers.
String? validateNewPassword(String? v) {
  final t = v ?? '';
  if (t.isEmpty) return 'أدخل كلمة المرور';
  if (t.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
  if (!RegExp(r'[A-Za-z؀-ۿ]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) {
    return 'كلمة المرور يجب أن تحتوي على حروف وأرقام';
  }
  return null;
}

String? validateOtp(String? v) {
  final t = v?.trim() ?? '';
  if (!RegExp(r'^\d{6}$').hasMatch(t)) return 'أدخل الرمز المكوّن من 6 أرقام';
  return null;
}
