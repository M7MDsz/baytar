import 'package:baytar/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sign-in function\'s own answers keep their meaning', () {
    expect(signInFailureReason({'error': 'invalid_credentials'}), 'invalid_credentials');
    expect(signInFailureReason({'error': 'locked', 'locked_until': '2026-11-08T20:00:00Z'}), 'locked');
    expect(signInFailureReason({'error': 'email_not_confirmed'}), 'email_not_confirmed');
  });

  // A friend ran the app against a local backend with no sign-in function, and was told the password was wrong.
  test('anything else is a connection problem, never "wrong password"', () {
    expect(signInFailureReason(null), 'unreachable'); // no body: the function does not exist or did not answer
    expect(signInFailureReason('<html>404</html>'), 'unreachable');
    expect(signInFailureReason({'message': 'Function not found'}), 'unreachable');
    expect(signInFailureReason({'error': 'server_error'}), 'unreachable');
  });
}
