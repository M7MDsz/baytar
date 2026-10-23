/// Form validators. Each returns an Arabic message, or null when the value is valid.
library;

String? requiredText(String? v, String field) =>
    (v == null || v.trim().isEmpty) ? 'أدخل $field' : null;

String? requiredChoice(Object? v, String field) => v == null ? 'اختر $field' : null;

String? optionalPositiveNumber(String? v, String field) {
  if (v == null || v.trim().isEmpty) return null;
  final n = num.tryParse(v.trim());
  if (n == null || n <= 0) return '$field يجب أن يكون رقماً أكبر من صفر';
  return null;
}

/// Animal age: at least one of age or date of birth is required (US-01).
String? ageOrBirthDate({required String? age, required DateTime? birthDate}) {
  if (birthDate != null) {
    return birthDate.isAfter(DateTime.now()) ? 'تاريخ الميلاد لا يمكن أن يكون في المستقبل' : null;
  }
  if (age == null || age.trim().isEmpty) return 'أدخل العمر أو تاريخ الميلاد';
  final n = num.tryParse(age.trim());
  if (n == null || n < 0 || n > 60) return 'أدخل عمراً صحيحاً بالسنوات';
  return null;
}
