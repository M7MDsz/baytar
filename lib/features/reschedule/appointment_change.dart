import '../booking/owner_appointment.dart';

/// Changes are allowed only while the appointment starts more than 12 hours from now (US-12, US-13).
bool canChangeAppointment(OwnerAppointment a, {DateTime? now}) =>
    a.status == 'booked' && a.startsAt.isAfter((now ?? DateTime.now()).add(const Duration(hours: 12)));

const changeErrors = {
  'too_late_to_change': 'لا يمكن تغيير الموعد أو إلغاؤه قبل بدايته بأقل من 12 ساعة.',
  'slot_unavailable': 'لم يعد هذا الموعد متاحاً. اختر موعداً آخر.',
  'not_booked': 'هذا الموعد لم يعد محجوزاً.',
};
