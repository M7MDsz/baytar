import 'dart:io';

import '../../core/storage.dart';
import '../../core/supabase.dart';

const vetRegistrationErrors = {
  'license_taken': 'رقم الترخيص مسجّل مسبقاً.',
  'license_expiry_not_future': 'تاريخ انتهاء الترخيص يجب أن يكون في المستقبل.',
  'missing_fields': 'أكمل جميع الحقول المطلوبة.',
  'already_registered': 'تم إرسال بيانات الترخيص مسبقاً.',
  'not_a_vet_account': 'هذا الحساب ليس حساب طبيب بيطري.',
};

const maxLicenseBytes = 10 * 1024 * 1024;
const licenseExtensions = {'pdf', 'jpg', 'jpeg', 'png'};

/// Returns an Arabic reason when the license file is not accepted.
String? licenseFileRejection(String extension, int sizeBytes) {
  if (!licenseExtensions.contains(extension.toLowerCase())) return 'ملف الترخيص يجب أن يكون PDF أو JPG أو PNG.';
  if (sizeBytes > maxLicenseBytes) return 'حجم ملف الترخيص أكبر من 10 ميجابايت.';
  return null;
}

/// Professional details collected by US-31; saved after the email code is confirmed.
class VetApplication {
  const VetApplication({
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.licenseFile,
    required this.specialties,
    required this.animalTypes,
    required this.languages,
    this.bio,
  });

  final String licenseNumber;
  final DateTime licenseExpiry;
  final File licenseFile;
  final List<String> specialties;
  final List<String> animalTypes;
  final List<String> languages;
  final String? bio;

  static Future<bool> licenseNumberTaken(String number) async =>
      await db.rpc('license_number_taken', params: {'p_number': number.trim()}) as bool;

  /// Uploads the license and creates the Pending verification profile. Needs a signed-in vet account.
  Future<void> submit() async {
    final ext = extensionOf(licenseFile.path);
    final path = await uploadFile(
      'licenses',
      userFilePath('license', ext),
      licenseFile,
      contentType: ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg'),
    );
    final expiry = licenseExpiry;
    await db.rpc('register_vet_profile', params: {
      'p_license_number': licenseNumber.trim(),
      'p_license_expiry': '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',
      'p_license_path': path,
      'p_specialties': specialties,
      'p_animal_types': animalTypes,
      'p_languages': languages,
      'p_bio': bio,
    });
  }
}
