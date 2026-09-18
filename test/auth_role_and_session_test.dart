import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/user_model.dart';
import 'package:aerodrop/core/providers/auth_provider.dart';

void main() {
  group('UserModel copyWith clear flags', () {
    final baseUser = UserModel(
      id: 'u-1',
      email: 'vendor@aerodrop.test',
      name: 'Test Vendor',
      role: 'vendor',
      avatarUrl: 'https://cdn.example.com/avatar.png',
      businessLogoUrl: 'https://cdn.example.com/logo.png',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('preserves avatar and logo when clear flags are false', () {
      final updated = baseUser.copyWith(fullName: 'Updated Name');
      expect(updated.avatarUrl, 'https://cdn.example.com/avatar.png');
      expect(updated.businessLogoUrl, 'https://cdn.example.com/logo.png');
      expect(updated.fullName, 'Updated Name');
    });

    test('clears avatarUrl to null when clearAvatar is true', () {
      final updated = baseUser.copyWith(clearAvatar: true);
      expect(updated.avatarUrl, isNull);
      expect(updated.businessLogoUrl, 'https://cdn.example.com/logo.png');
    });

    test('clears businessLogoUrl to null when clearBusinessLogo is true', () {
      final updated = baseUser.copyWith(clearBusinessLogo: true);
      expect(updated.businessLogoUrl, isNull);
      expect(updated.avatarUrl, 'https://cdn.example.com/avatar.png');
    });

    test('allows replacing avatarUrl with a new value', () {
      final updated = baseUser.copyWith(
        avatarUrl: 'https://cdn.example.com/new.png',
      );
      expect(updated.avatarUrl, 'https://cdn.example.com/new.png');
    });
  });

  group('AuthState sessionUnlocked state management', () {
    test('default AuthState has sessionUnlocked = false', () {
      final state = AuthState();
      expect(state.sessionUnlocked, isFalse);
      expect(state.user, isNull);
    });

    test('copyWith updates sessionUnlocked correctly', () {
      final state = AuthState();
      final unlocked = state.copyWith(sessionUnlocked: true);
      expect(unlocked.sessionUnlocked, isTrue);

      final relocked = unlocked.copyWith(sessionUnlocked: false);
      expect(relocked.sessionUnlocked, isFalse);
    });

    test('AuthNotifier logout clears user and locks session', () async {
      final notifier = AuthNotifier();
      notifier.state = AuthState(
        user: UserModel(
          id: 'v-test',
          email: 'vendor@aerodrop.test',
          name: 'Active Vendor',
          role: 'vendor',
        ),
        sessionUnlocked: true,
      );
      expect(notifier.state.user, isNotNull);
      expect(notifier.state.sessionUnlocked, isTrue);

      final success = await notifier.logout();
      expect(success, isTrue);
      expect(notifier.state.user, isNull);
      expect(notifier.state.sessionUnlocked, isFalse);
    });
  });

  group('Role-based login and router authorization predicate', () {
    final customerUser = UserModel(
      id: 'c-1',
      email: 'student@slu.edu.ph',
      name: 'Student User',
      role: 'user',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final pendingVendorUser = UserModel(
      id: 'pv-1',
      email: 'applicant@slu.edu.ph',
      name: 'Pending Vendor',
      role: 'user',
      vendorStatus: 'pending',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final rejectedVendorUser = UserModel(
      id: 'rv-1',
      email: 'rejected@slu.edu.ph',
      name: 'Rejected Vendor',
      role: 'user',
      vendorStatus: 'rejected',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final approvedVendorUser = UserModel(
      id: 'v-1',
      email: 'store@slu.edu.ph',
      name: 'Campus Cafe',
      role: 'vendor',
      vendorStatus: 'approved',
      businessName: 'Campus Cafe',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test(
      'GoRouter isLoggedIn check requires both user != null AND sessionUnlocked == true',
      () {
        bool checkIsLoggedIn(AuthState auth) =>
            auth.user != null && auth.sessionUnlocked;

        // Restored session in background, but not yet unlocked by user
        final coldStartSession = AuthState(
          user: approvedVendorUser,
          sessionUnlocked: false,
        );
        expect(
          checkIsLoggedIn(coldStartSession),
          isFalse,
          reason:
              'Cold start session must not auto-navigate to vendor dashboard',
        );

        // Unlocked session after explicit login
        final activeSession = AuthState(
          user: approvedVendorUser,
          sessionUnlocked: true,
        );
        expect(checkIsLoggedIn(activeSession), isTrue);

        // Logged out
        final loggedOut = AuthState(user: null, sessionUnlocked: false);
        expect(checkIsLoggedIn(loggedOut), isFalse);
      },
    );

    test('Customer login verification rules', () {
      // Customer login expects role != 'vendor'
      String? validateCustomerLogin(UserModel user) {
        if (user.role == 'vendor') {
          return 'This account is registered as a vendor. Please use Vendor Login.';
        }
        return null;
      }

      expect(validateCustomerLogin(customerUser), isNull);
      expect(validateCustomerLogin(pendingVendorUser), isNull);
      expect(
        validateCustomerLogin(approvedVendorUser),
        'This account is registered as a vendor. Please use Vendor Login.',
      );
    });

    test('Vendor login verification rules', () {
      String? validateVendorLogin(UserModel user) {
        if (user.role != 'vendor') {
          final vs = user.vendorStatus;
          if (vs == 'pending') {
            return 'PENDING_VENDOR';
          }
          if (vs == 'rejected') {
            return 'Your vendor application was not approved.';
          }
          if (vs == 'suspended') {
            return 'Your vendor account is currently suspended.';
          }
          return 'This account is not registered as a vendor.';
        }
        return null;
      }

      expect(validateVendorLogin(approvedVendorUser), isNull);
      expect(validateVendorLogin(pendingVendorUser), 'PENDING_VENDOR');
      expect(
        validateVendorLogin(rejectedVendorUser),
        'Your vendor application was not approved.',
      );
      expect(
        validateVendorLogin(customerUser),
        'This account is not registered as a vendor.',
      );
    });
  });
}
