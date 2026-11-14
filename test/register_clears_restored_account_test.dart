import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creating an account on a device that restored someone else's session
/// must start from no account at all. `copyWith(user: null)` keeps the
/// current user, which used to send sign-up to the old account's code screen.
void main() {
  final restored = AeroDropUser(
    id: 'old-account',
    email: 'previous.user@gmail.com',
    role: 'user',
  );

  test('copyWith(user: null) keeps the user, as before', () {
    final s = AuthState(user: restored).copyWith(user: null);
    expect(s.user?.email, 'previous.user@gmail.com');
  });

  test('clearUser drops a restored account', () {
    final s = AuthState(user: restored).copyWith(
      clearUser: true,
      requiresVerification: true,
      pendingEmail: 'new.person@gmail.com',
    );
    expect(s.user, isNull);
    expect(s.pendingEmail, 'new.person@gmail.com');
    expect(s.requiresVerification, isTrue);
  });
}
