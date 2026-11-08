import 'package:baytar/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('a refused sign-up says why', () {
    test('Supabase error codes map to what the user can act on', () {
      Object map(String code, [String message = 'x', String status = '400']) =>
          signUpFailure(AuthException(message, statusCode: status, code: code));

      expect(map('email_address_invalid'), isA<SignUpRefused>().having((e) => e.reason, 'reason', 'email_invalid'));
      expect(map('weak_password'), isA<SignUpRefused>().having((e) => e.reason, 'reason', 'weak_password'));
      for (final code in [
        'email_address_not_authorized',
        'over_email_send_rate_limit',
        'over_request_rate_limit',
        'unexpected_failure',
      ]) {
        expect(map(code), isA<SignUpRefused>().having((e) => e.reason, 'reason', 'code_not_sent'), reason: code);
      }
      expect(map('user_already_exists'), isA<AccountExists>());
      expect(map('email_exists'), isA<AccountExists>());
    });

    test('older servers without a code are recognised by message or status', () {
      Object map(String message, [String status = '400']) => signUpFailure(AuthException(message, statusCode: status));

      expect(map('User already registered'), isA<AccountExists>());
      expect(map('Error sending confirmation email', '500'), isA<SignUpRefused>());
      expect(map('email rate limit exceeded', '429'), isA<SignUpRefused>());
      expect(map('Too many requests', '429'), isA<SignUpRefused>());
      final other = AuthException('Database error saving new user', statusCode: '500');
      expect(signUpFailure(other), same(other));
    });

    test('every refusal has its own Arabic message, not the generic one', () {
      const generic = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      expect(signUpErrorMessage(AccountExists()), 'يوجد حساب مسجّل بهذا البريد الإلكتروني');
      for (final reason in ['email_invalid', 'code_not_sent', 'weak_password']) {
        final text = signUpErrorMessage(SignUpRefused(reason));
        expect(text, signUpRefusals[reason]);
        expect(text, isNot(generic));
      }
      expect(signUpErrorMessage(SignUpRefused('email_invalid')), contains('البريد الإلكتروني غير صالح'));
      expect(signUpErrorMessage(SignUpRefused('code_not_sent')), contains('تعذّر إرسال رمز التحقق'));
      expect(signUpErrorMessage(Exception('boom')), generic);
    });
  });

  group('after a successful sign-up', () {
    test('no session: the 6-digit code screen comes next', () {
      expect(signUpOutcome(null), SignUpOutcome.codeSent);
    });

    test('a session (no code needed): the user is signed in straight away', () {
      final session = Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: const User(id: 'u', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-11-08'),
      );
      expect(signUpOutcome(session), SignUpOutcome.signedIn);
    });
  });
}
