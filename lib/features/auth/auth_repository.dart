import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/supabase.dart';

class AccountExists implements Exception {}

/// The server refused a sign-up for a reason the user can act on. [reason] is a key of [signUpRefusals].
class SignUpRefused implements Exception {
  const SignUpRefused(this.reason);

  final String reason;
}

const signUpRefusals = {
  'email_invalid': 'البريد الإلكتروني غير صالح. تأكد منه وحاول مرة أخرى.',
  'code_not_sent': 'تعذّر إرسال رمز التحقق الآن، حاول لاحقاً.',
  'weak_password': 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل تجمع بين حروف وأرقام.',
};

/// The Arabic text for a failed sign-up, shown in a snack bar on the owner and veterinarian forms.
String signUpErrorMessage(Object error) => switch (error) {
      AccountExists() => 'يوجد حساب مسجّل بهذا البريد الإلكتروني',
      SignUpRefused(:final reason) => signUpRefusals[reason]!,
      _ => friendlyError(error),
    };

/// Turns Supabase's sign-up error into [AccountExists] or [SignUpRefused]. Anything else is returned unchanged.
Object signUpFailure(AuthException e) {
  final message = e.message.toLowerCase();
  return switch (e.code) {
    'user_already_exists' || 'email_exists' => AccountExists(),
    'email_address_invalid' => const SignUpRefused('email_invalid'),
    'weak_password' => const SignUpRefused('weak_password'),
    'email_address_not_authorized' ||
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' ||
    'unexpected_failure' =>
      const SignUpRefused('code_not_sent'),
    _ when message.contains('already registered') => AccountExists(),
    _ when message.contains('sending confirmation') || message.contains('rate limit') || e.statusCode == '429' =>
      const SignUpRefused('code_not_sent'),
    _ => e,
  };
}

/// With email confirmation on, sign-up returns no session and the 6-digit code comes next; with it off, the
/// session is already there.
SignUpOutcome signUpOutcome(Session? session) => session == null ? SignUpOutcome.codeSent : SignUpOutcome.signedIn;

/// What happened after a successful sign-up.
enum SignUpOutcome {
  /// The server needs the 6-digit code from the email first.
  codeSent,

  /// The server confirmed the account straight away and returned a session: the user is signed in.
  signedIn,
}

class SignInRefused implements Exception {
  const SignInRefused(this.reason);

  /// invalid_credentials, locked or email_not_confirmed.
  final String reason;
}

class AuthRepository {
  /// Creates the account. [role] is 'owner' or 'vet'. Throws [AccountExists] or [SignUpRefused] with a reason the
  /// screen can show. Returns [SignUpOutcome.signedIn] when the server confirmed the account without the emailed code.
  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required bool termsAccepted,
    String role = 'owner',
  }) async {
    final AuthResponse res;
    try {
      res = await db.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': fullName.trim(), 'mobile': mobile.trim(), 'role': role, 'terms_accepted': termsAccepted},
      );
    } on AuthException catch (e) {
      throw signUpFailure(e);
    }
    // Supabase answers an already-registered email with a user that has no identities.
    if (res.user?.identities?.isEmpty ?? false) throw AccountExists();
    return signUpOutcome(res.session);
  }

  Future<void> verifySignUpCode(String email, String code) =>
      db.auth.verifyOTP(type: OtpType.signup, email: email.trim().toLowerCase(), token: code.trim());

  Future<void> resendSignUpCode(String email) =>
      db.auth.resend(type: OtpType.signup, email: email.trim().toLowerCase());

  /// Goes through the sign-in Edge Function, which counts failures and locks after 5.
  Future<void> signIn(String email, String password) async {
    try {
      final res = await db.functions.invoke('sign-in', body: {'email': email, 'password': password});
      final data = res.data as Map<String, dynamic>;
      await db.auth.setSession(data['refresh_token'] as String);
    } on FunctionException catch (e) {
      final details = e.details;
      throw SignInRefused(details is Map ? (details['error'] as String? ?? 'invalid_credentials') : 'invalid_credentials');
    }
  }

  Future<void> sendPasswordReset(String email) => db.auth.resetPasswordForEmail(email.trim().toLowerCase());

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await db.auth.verifyOTP(type: OtpType.recovery, email: email.trim().toLowerCase(), token: code.trim());
    await db.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Takes this device's push token off the account first, so the next account signed in here does not receive
  /// its notifications (QA H-1). Signing out never fails or hangs because of that step.
  Future<void> signOut() async {
    try {
      await db.rpc('set_push_token', params: {'p_token': null}).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline or already signed out: the session still ends below.
    }
    await db.auth.signOut();
  }
}
