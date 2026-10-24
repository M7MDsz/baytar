import '../../core/formatting.dart';

class PendingVet {
  const PendingVet(this.data);

  final Map<String, dynamic> data;

  String get id => data['id'] as String;
  String get fullName => data['full_name'] as String;
  String get email => data['email'] as String;
  String? get mobile => data['mobile'] as String?;
  String get licenseNumber => data['license_number'] as String;
  DateTime get licenseExpiry => DateTime.parse(data['license_expiry'] as String);
  String get licensePath => data['license_path'] as String;
  List<String> get specialties => (data['specialties'] as List).cast<String>();
  List<String> get animalTypes => (data['animal_types'] as List).cast<String>();
  List<String> get languages => (data['languages'] as List).cast<String>();
  String? get bio => data['bio'] as String?;
  DateTime get submittedAt => parseTs(data['created_at']);
}
