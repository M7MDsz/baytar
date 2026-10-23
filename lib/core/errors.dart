import 'package:supabase_flutter/supabase_flutter.dart';

/// Database functions raise short codes (for example `slot_unavailable`).
/// Each screen passes the Arabic text for the codes it can receive.
String friendlyError(Object error, [Map<String, String> codes = const {}]) {
  final message = switch (error) {
    PostgrestException e => e.message,
    FunctionException e => '${e.details}',
    AuthException e => e.message,
    StorageException e => e.message,
    _ => error.toString(),
  };
  for (final entry in codes.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  if (message.contains('SocketException') || message.contains('Failed host lookup')) {
    return 'تعذر الاتصال بالإنترنت. حاول مرة أخرى.';
  }
  if (message.contains('permission denied') || message.contains('row-level security')) {
    return 'ليست لديك صلاحية لهذا الإجراء.';
  }
  return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}
