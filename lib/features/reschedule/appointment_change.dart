import '../booking/owner_appointment.dart';

/// US-12, US-13: an appointment can be rescheduled or cancelled only while it starts more than this far from now,
/// and a rescheduled appointment can only move to a slot that also starts more than this far from now.
/// The database applies the same boundary (`interval '12 hours'` in reschedule_appointment and cancel_appointment).
const changeCutoff = Duration(hours: 12);

/// True when [startsAt] is more than [changeCutoff] after [now].
bool isBeyondChangeCutoff(DateTime startsAt, {DateTime? now}) =>
    startsAt.isAfter((now ?? DateTime.now()).add(changeCutoff));

/// Changes are allowed only while the appointment starts more than 12 hours from now (US-12, US-13).
bool canChangeAppointment(OwnerAppointment a, {DateTime? now}) =>
    a.status == 'booked' && isBeyondChangeCutoff(a.startsAt, now: now);

const changeErrors = {
  'too_late_to_change': 'لا يمكن تغيير الموعد أو إلغاؤه قبل بدايته بأقل من 12 ساعة.',
  'slot_unavailable': 'لم يعد هذا الموعد متاحاً. اختر موعداً آخر.',
  'not_booked': 'هذا الموعد لم يعد محجوزاً.',
};
