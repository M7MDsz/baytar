import 'package:baytar/features/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

// US-29 sign-up rules.
void main() {
  test('email format', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('owner@'), isNotNull);
    expect(validateEmail('owner@example'), isNotNull);
    expect(validateEmail('owner@example.com'), isNull);
  });

  test('mobile is 10 digits starting with 05', () {
    expect(validateMobile('0551234567'), isNull);
    expect(validateMobile('055123456'), isNotNull);
    expect(validateMobile('0651234567'), isNotNull);
    expect(validateMobile('+966551234567'), isNotNull);
  });

  test('password needs 8+ characters with letters and numbers', () {
    expect(validateNewPassword('abc12'), isNotNull);
    expect(validateNewPassword('abcdefgh'), isNotNull);
    expect(validateNewPassword('12345678'), isNotNull);
    expect(validateNewPassword('baytar2026'), isNull);
  });

  test('the email code is 6 digits', () {
    expect(validateOtp('12345'), isNotNull);
    expect(validateOtp('12a456'), isNotNull);
    expect(validateOtp('123456'), isNull);
  });
}
