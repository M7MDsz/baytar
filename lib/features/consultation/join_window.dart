import '../../core/session.dart';

/// When the Join button is shown. The server checks the same windows again (join_consultation).
/// Owner: 10 minutes before to 15 minutes after the start (US-14). Veterinarian: 15 before to 15 after (US-19).
bool canJoinNow(DateTime startsAt, UserRole role, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final before = role == UserRole.vet ? 15 : 10;
  return !t.isBefore(startsAt.subtract(Duration(minutes: before))) &&
      !t.isAfter(startsAt.add(const Duration(minutes: 15)));
}

/// 'too_early' or 'too_late' when outside the window, otherwise null.
String? joinBlockedReason(DateTime startsAt, UserRole role, {DateTime? now}) {
  if (canJoinNow(startsAt, role, now: now)) return null;
  return (now ?? DateTime.now()).isBefore(startsAt) ? 'too_early' : 'too_late';
}

const joinRefusedText = <String, String>{
  'too_early': 'لم يحن وقت الاستشارة بعد. يمكنك الدخول قبل الموعد بدقائق.',
  'too_late': 'انتهى وقت الدخول إلى هذه الاستشارة.',
  'cancelled': 'هذا الموعد ملغى.',
  'forbidden': 'لا يمكنك الدخول إلى هذه الاستشارة.',
  'not_found': 'لم يتم العثور على الموعد.',
};
