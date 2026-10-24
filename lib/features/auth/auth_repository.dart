import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

class AccountExists implements Exception {}

class SignInRefused implements Exception {
  const SignInRefused(this.reason);

  /// invalid_credentials, locked or email_not_confirmed.
  final String reason;
}

class AuthRepository {
  /// Creates the account and sends the 6-digit code. [role] is 'owner' or 'vet'.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required bool termsAccepted,
    String role = 'owner',
  }) async {
    final res = await db.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'full_name': fullName.trim(), 'mobile': mobile.trim(), 'role': role, 'terms_accepted': termsAccepted},
    );
    // Supabase answers an already-registered email with a user that has no identities.
    if (res.user?.identities?.isEmpty ?? false) throw AccountExists();
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

  Future<void> signOut() => db.auth.signOut();
}
