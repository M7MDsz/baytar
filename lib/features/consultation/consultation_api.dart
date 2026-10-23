import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'join_window.dart';

class JoinRefused implements Exception {
  const JoinRefused(this.reason);

  final String reason;

  String get message => joinRefusedText[reason] ?? 'تعذر الدخول إلى الاستشارة.';
}

typedef RoomAccess = ({String url, String token});

/// Asks the server for a video token. Throws [JoinRefused] with the reason when entry is refused.
Future<RoomAccess> fetchRoomAccess(String appointmentId) async {
  try {
    final res = await db.functions.invoke('consultation-token', body: {'appointmentId': appointmentId});
    final data = res.data as Map<String, dynamic>;
    return (url: data['url'] as String, token: data['token'] as String);
  } on FunctionException catch (e) {
    final details = e.details;
    final reason = details is Map ? details['error'] as String? : null;
    throw JoinRefused(reason ?? 'server_error');
  }
}
