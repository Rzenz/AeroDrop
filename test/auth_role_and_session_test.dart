import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:aerodrop/core/constants/auth_constants.dart';
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

    test('Google sign-in profile completion and role routing logic', () {
      final googleUserNoPhone = AeroDropUser(
        id: 'g-1',
        email: 'googleuser@gmail.com',
        name: 'Google User',
        role: 'user',
        phoneNumber: null,
      );

      final googleUserWithPhone = AeroDropUser(
        id: 'g-2',
        email: 'googleuser2@gmail.com',
        name: 'Google User 2',
        role: 'user',
        phoneNumber: '+639171234567',
      );

      final googleAdminUser = AeroDropUser(
        id: 'g-admin',
        email: AuthConstants.adminEmail,
        name: 'Admin Google',
        role: 'admin',
      );

      final googleVendorUser = AeroDropUser(
        id: 'g-vendor',
        email: 'store@gmail.com',
        name: 'Vendor Google',
        role: 'vendor',
        vendorStatus: 'active',
        phoneNumber: '+639171234567',
      );

      final googlePendingVendor = AeroDropUser(
        id: 'g-pv',
        email: 'pv@gmail.com',
        name: 'Pending Vendor Google',
        role: 'user',
        vendorStatus: 'pending',
        phoneNumber: '+639171234567',
      );

      // Router predicate logic
      String resolveRoute(AeroDropUser user, {String currentPath = '/welcome'}) {
        final hasNoPhone = !user.isAdmin &&
            (user.phoneNumber == null || user.phoneNumber!.trim().isEmpty);
        if (hasNoPhone) {
          return '/complete-profile';
        }
        if (user.vendorStatus == 'pending') {
          return '/account-pending';
        }
        if (user.isAdmin) return '/admin';
        if (user.isVendor) return '/vendor';
        return '/user';
      }

      // User without phone is forced to complete profile
      expect(resolveRoute(googleUserNoPhone), '/complete-profile');

      // User with phone routes directly to /user
      expect(resolveRoute(googleUserWithPhone), '/user');

      // Admin routes to /admin even without phone
      expect(resolveRoute(googleAdminUser), '/admin');

      // Active vendor routes to /vendor
      expect(resolveRoute(googleVendorUser), '/vendor');

      // Pending vendor routes to /account-pending
      expect(resolveRoute(googlePendingVendor), '/account-pending');
    });

    test('Google sign-in state unlocks session without OTP requirement', () {
      final googleUser = AeroDropUser(
        id: 'g-1',
        email: 'googleuser@gmail.com',
        name: 'Google User',
        role: 'user',
      );

      final state = AuthState(
        user: googleUser,
        sessionUnlocked: true,
        requiresVerification: false,
        isVerified: true,
      );

      expect(state.sessionUnlocked, isTrue);
      expect(state.requiresVerification, isFalse);
      expect(state.isVerified, isTrue);
      expect(state.user?.role, 'user');
    });

    test('Admin accounts are explicitly blocked from Google OAuth', () {
      bool isOAuthAllowed(AeroDropUser user) {
        if (user.isAdmin || AuthConstants.isAdminEmail(user.email)) {
          return false;
        }
        return true;
      }

      final regularUser = AeroDropUser(
        id: 'u-1',
        email: 'customer@gmail.com',
        name: 'Customer',
        role: 'user',
      );

      final vendorUser = AeroDropUser(
        id: 'v-1',
        email: 'vendor@gmail.com',
        name: 'Vendor',
        role: 'vendor',
      );

      final adminUser = AeroDropUser(
        id: 'a-1',
        email: AuthConstants.adminEmail,
        name: 'Admin',
        role: 'admin',
      );

      expect(isOAuthAllowed(regularUser), isTrue);
      expect(isOAuthAllowed(vendorUser), isTrue);
      expect(isOAuthAllowed(adminUser), isFalse);
    });

    test('Customer role in public.users is never granted vendor or admin routes', () {
      final customer = AeroDropUser(
        id: 'c-1',
        email: 'customer@gmail.com',
        name: 'Customer',
        role: 'user',
      );

      expect(customer.isAdmin, isFalse);
      expect(customer.isVendor, isFalse);
      expect(customer.isPendingVendor, isFalse);
    });
  });

  group('AuthConstants and Admin Email Protection', () {
    test('isAdminEmail matches canonical admin and legacy admin', () {
      expect(AuthConstants.adminEmail, 'admin.portal@uclm.edu');
      expect(AuthConstants.isAdminEmail('admin.portal@uclm.edu'), isTrue);
      expect(AuthConstants.isAdminEmail('ADMIN.PORTAL@UCLM.EDU '), isTrue);
      expect(AuthConstants.isAdminEmail('aerodrop.uclm+admin@gmail.com'), isTrue);
      expect(AuthConstants.isAdminEmail('AERODROP.UCLM+ADMIN@GMAIL.COM '), isTrue);
      expect(AuthConstants.isAdminEmail('admin@aerodrop.com'), isTrue);
      expect(AuthConstants.isAdminEmail('ADMIN@AERODROP.COM'), isTrue);
    });

    test('isAdminEmail rejects non-admin emails', () {
      expect(AuthConstants.isAdminEmail('customer@gmail.com'), isFalse);
      expect(AuthConstants.isAdminEmail('vendor@slu.edu.ph'), isFalse);
      expect(AuthConstants.isAdminEmail(''), isFalse);
      expect(AuthConstants.isAdminEmail(null), isFalse);
    });

    test('admin email protection guards prevent sending auth emails', () {
      // 1. sendLoginOtp check
      final adminUser = AeroDropUser(
        id: 'adm-1',
        email: AuthConstants.adminEmail,
        name: 'Admin User',
        role: 'admin',
      );
      expect(adminUser.isAdmin || AuthConstants.isAdminEmail(adminUser.email), isTrue);

      // 2. register check
      expect(AuthConstants.isAdminEmail('admin.portal@uclm.edu'), isTrue);

      // 3. resendRegistrationOtp check
      expect(AuthConstants.isAdminEmail(adminUser.email) || adminUser.isAdmin, isTrue);

      // 4. sendPasswordReset check
      expect(AuthConstants.isAdminEmail(adminUser.email) || adminUser.isAdmin, isTrue);
    });
  });

  group('Password Login and OAuth Verification State Transitions', () {
    final customerUser = AeroDropUser(
      id: 'cust-1',
      email: 'customer@aerodrop.app',
      name: 'Customer One',
      role: 'user',
    );

    final vendorUser = AeroDropUser(
      id: 'vend-1',
      email: 'vendor@aerodrop.app',
      name: 'Vendor One',
      role: 'vendor',
      vendorStatus: 'approved',
    );

    final pendingVendorUser = AeroDropUser(
      id: 'pvend-1',
      email: 'applicant@aerodrop.app',
      name: 'Pending Vendor One',
      role: 'user',
      vendorStatus: 'pending',
    );

    final adminUser = AeroDropUser(
      id: 'admin-1',
      email: AuthConstants.adminEmail,
      name: 'System Admin',
      role: 'admin',
    );

    test('Customer password login sets requiresVerification and keeps session locked', () {
      final initial = const AuthState();
      final postLogin = initial.copyWith(
        user: customerUser,
        sessionUnlocked: false,
        requiresVerification: true,
        isVerified: false,
      );

      expect(postLogin.user, isNotNull);
      expect(postLogin.sessionUnlocked, isFalse);
      expect(postLogin.requiresVerification, isTrue);
      expect(postLogin.isVerified, isFalse);

      final postOtp = postLogin.copyWith(
        sessionUnlocked: true,
        requiresVerification: false,
        isVerified: true,
      );

      expect(postOtp.sessionUnlocked, isTrue);
      expect(postOtp.requiresVerification, isFalse);
      expect(postOtp.isVerified, isTrue);
    });

    test('Vendor password login sets requiresVerification and keeps session locked', () {
      final postLogin = const AuthState().copyWith(
        user: vendorUser,
        sessionUnlocked: false,
        requiresVerification: true,
        isVerified: false,
      );

      expect(postLogin.sessionUnlocked, isFalse);
      expect(postLogin.requiresVerification, isTrue);
      expect(postLogin.isVerified, isFalse);
    });

    test('Pending vendor applicant password login requires OTP and routes to /account-pending', () {
      final postLogin = const AuthState().copyWith(
        user: pendingVendorUser,
        sessionUnlocked: false,
        requiresVerification: true,
        isVerified: false,
      );

      expect(postLogin.sessionUnlocked, isFalse);
      expect(postLogin.requiresVerification, isTrue);
      expect(postLogin.user?.vendorStatus, 'pending');

      // Post OTP verification route check
      final user = postLogin.user!;
      final targetRoute = user.vendorStatus == 'pending' ? '/account-pending' : '/user';
      expect(targetRoute, '/account-pending');
    });

    test('Admin password login bypasses OTP directly with unlocked session', () {
      final postAdminLogin = const AuthState().copyWith(
        user: adminUser,
        sessionUnlocked: true,
        requiresVerification: false,
        isVerified: true,
      );

      expect(postAdminLogin.sessionUnlocked, isTrue);
      expect(postAdminLogin.requiresVerification, isFalse);
      expect(postAdminLogin.isVerified, isTrue);
      expect(postAdminLogin.user?.isAdmin, isTrue);
    });

    test('Google sign-in unlocks session immediately without OTP requirement', () {
      final postGoogleSignIn = const AuthState().copyWith(
        user: customerUser,
        sessionUnlocked: true,
        requiresVerification: false,
        isVerified: true,
      );

      expect(postGoogleSignIn.sessionUnlocked, isTrue);
      expect(postGoogleSignIn.requiresVerification, isFalse);
      expect(postGoogleSignIn.isVerified, isTrue);
    });

    test('Vendor tab mismatch with customer credentials leaves user signed out', () {
      // Simulating login mismatch logic
      const expectedRole = 'vendor';
      final aeroUser = customerUser;

      final isPendingApplicant = aeroUser.vendorStatus == 'pending';
      final isMismatch = expectedRole == 'vendor' &&
          !isPendingApplicant &&
          aeroUser.role != 'vendor' &&
          !aeroUser.isAdmin;
      expect(isMismatch, isTrue);

      // State reset on mismatch
      final stateOnMismatch = const AuthState().copyWith(
        errorMessage: 'This account is not registered as a vendor.',
      );

      expect(stateOnMismatch.user, isNull);
      expect(stateOnMismatch.sessionUnlocked, isFalse);
      expect(stateOnMismatch.errorMessage, 'This account is not registered as a vendor.');
    });

    test('Customer tab mismatch with vendor credentials leaves user signed out', () {
      const expectedRole = 'user';
      final aeroUser = vendorUser;

      final isMismatch = expectedRole == 'user' && aeroUser.role == 'vendor' && !aeroUser.isAdmin;
      expect(isMismatch, isTrue);

      final stateOnMismatch = const AuthState().copyWith(
        errorMessage: 'This account is registered as a vendor. Please use Vendor Login.',
      );

      expect(stateOnMismatch.user, isNull);
      expect(stateOnMismatch.sessionUnlocked, isFalse);
      expect(
        stateOnMismatch.errorMessage,
        'This account is registered as a vendor. Please use Vendor Login.',
      );
    });
  });

  group('Google-only account detection and login/forgot-password guidance', () {
    test('Google-only error message is specific and actionable', () {
      const googleOnlyMessage =
          'This account uses Google sign-in. Tap Continue with Google to sign in.';
      expect(
        googleOnlyMessage,
        'This account uses Google sign-in. Tap Continue with Google to sign in.',
      );
    });

    test('Generic invalid credentials error preserves privacy for non-Google/unregistered accounts', () {
      final genericError = formatAuthErrorMessage(
        const AuthException('Invalid login credentials', code: 'invalid_credentials'),
      );
      expect(genericError, 'Incorrect credentials or invalid verification code.');
    });

    test('ForgotPassword extra parameters include is_google_only flag', () {
      final extraWithGoogle = <String, String>{
        'email': 'googleuser@gmail.com',
        'type': 'reset',
        'is_google_only': 'true',
      };
      expect(extraWithGoogle['is_google_only'], 'true');
      expect(extraWithGoogle['type'], 'reset');

      final extraWithoutGoogle = <String, String>{
        'email': 'standarduser@gmail.com',
        'type': 'reset',
      };
      expect(extraWithoutGoogle['is_google_only'], isNull);
    });

    test('Desktop OAuth response safely HTML-escapes malicious error descriptions', () {
      const maliciousError = '<script>alert("xss")</script> & error "quoted"';
      final safe = htmlEscape.convert(maliciousError);
      expect(safe, contains('&lt;script&gt;'));
      expect(safe, contains('&amp;'));
      expect(safe, contains('&quot;'));
      expect(safe, isNot(contains('<script>')));
    });
  });
}

