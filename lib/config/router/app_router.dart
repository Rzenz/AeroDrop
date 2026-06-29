import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';

import 'auth_guard.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/verification_page.dart';
import '../../features/auth/presentation/pages/account_pending_page.dart';

import '../../features/dashboard/user_shell.dart';
import '../../features/dashboard/user_dashboard_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/tracking/tracking_details_page.dart';
import '../../features/delivery/delivery_history_screen.dart';
import '../../features/delivery/delivery_request_screen.dart';
import '../../features/delivery/presentation/pages/delivery_summary_page.dart';
import '../../features/delivery/presentation/pages/delivery_success_page.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/notifications/notification_details_page.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/change_password_page.dart';
import '../../features/profile/settings_page.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/user_details_page.dart';
import '../../features/admin/edit_user_page.dart';
import '../../features/admin/user_activity_page.dart';
import '../../features/admin/admin_drones_screen.dart';
import '../../features/admin/add_edit_drone_screen.dart';
import '../../features/admin/drone_details_page.dart';
import '../../features/admin/drone_monitoring_page.dart';
import '../../features/admin/admin_deliveries_screen.dart';
import '../../features/admin/delivery_details_screen.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/admin_settings_screen.dart';
import '../../features/admin/mission_list_page.dart';
import '../../features/admin/mission_details_page.dart';
import '../../features/admin/route_planner_page.dart';
import '../../features/admin/no_fly_zone_page.dart';
import '../../features/admin/create_no_fly_zone_page.dart';
import '../../features/admin/edit_no_fly_zone_page.dart';
import '../../features/admin/reports_page.dart';
import '../../features/admin/delivery_reports_page.dart';
import '../../features/admin/drone_reports_page.dart';
import '../../features/admin/user_reports_page.dart';

import '../../features/shared/about_page.dart';
import '../../features/shared/help_support_page.dart';
import '../../features/shared/privacy_policy_page.dart';
import '../../features/shared/terms_conditions_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref.watch(authProvider.notifier).stream),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final isLoggedIn = user != null;
      final isLoggingIn = state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/onboarding' ||
          state.uri.path == '/splash';

      if (!isLoggedIn) {
        if (!isLoggingIn) {
          return '/login';
        }
        return null;
      }

      if (isLoggingIn) {
        return user.role == UserRole.admin ? '/admin' : '/user';
      }

      final isAdminPath = state.uri.path.startsWith('/admin');
      final isUserPath = state.uri.path.startsWith('/user');

      if (isAdminPath && user.role != UserRole.admin) {
        return '/user';
      }
     if (isUserPath && user.role == UserRole.admin) {
  return '/admin';
}

      return null;
    },
    routes: [
      // ─── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slide(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _slide(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/verification',
        pageBuilder: (context, state) => _fade(state, const VerificationPage()),
      ),
      GoRoute(
        path: '/account-pending',
        pageBuilder: (context, state) => _fade(state, const AccountPendingPage()),
      ),

      // ─── User Shell (Bottom Nav) ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/user',
            pageBuilder: (context, state) => _fade(state, const UserDashboardScreen()),
          ),
          GoRoute(
            path: '/user/track',
            pageBuilder: (context, state) => _fade(state, const TrackingScreen()),
          ),
          GoRoute(
            path: '/user/history',
            pageBuilder: (context, state) => _fade(state, const DeliveryHistoryScreen()),
          ),
          GoRoute(
            path: '/user/notifications',
            pageBuilder: (context, state) => _fade(state, const NotificationsScreen()),
          ),
          GoRoute(
            path: '/user/profile',
            pageBuilder: (context, state) => _fade(state, const ProfileScreen()),
          ),
        ],
      ),

      // ─── User Full-Screen Pushes ─────────────────────────────────────────
      GoRoute(
        path: '/user/request',
        pageBuilder: (context, state) => _slide(state, const DeliveryRequestScreen()),
      ),
      GoRoute(
        path: '/user/profile/edit',
        pageBuilder: (context, state) => _slide(state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/user/profile/change-password',
        pageBuilder: (context, state) => _slide(state, const ChangePasswordPage()),
      ),
      GoRoute(
        path: '/user/settings',
        pageBuilder: (context, state) => _slide(state, const SettingsPage()),
      ),
      GoRoute(
        path: '/user/delivery/summary',
        pageBuilder: (context, state) => _slide(state, const DeliverySummaryPage()),
      ),
      GoRoute(
        path: '/user/delivery/success',
        pageBuilder: (context, state) => _slide(state, const DeliverySuccessPage()),
      ),
      GoRoute(
        path: '/user/track/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, TrackingDetailsPage(deliveryId: deliveryId));
        },
      ),
      GoRoute(
        path: '/user/notifications/details',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _slide(state, NotificationDetailsPage(notificationId: id));
        },
      ),

      // ─── Admin Shell (Drawer) ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => _fade(state, const AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (context, state) => _fade(state, const AdminUsersScreen()),
          ),
          GoRoute(
            path: '/admin/drones',
            pageBuilder: (context, state) => _fade(state, const AdminDronesScreen()),
          ),
          GoRoute(
            path: '/admin/deliveries',
            pageBuilder: (context, state) => _fade(state, const AdminDeliveriesScreen()),
          ),
          GoRoute(
            path: '/admin/analytics',
            pageBuilder: (context, state) => _fade(state, const AdminAnalyticsScreen()),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) => _fade(state, const AdminSettingsScreen()),
          ),
        ],
      ),

      // ─── Admin Full-Screen Pushes ────────────────────────────────────────
      GoRoute(
        path: '/admin/drones/add',
        pageBuilder: (context, state) => _slide(state, const AddEditDroneScreen()),
      ),
      GoRoute(
        path: '/admin/drones/edit',
        pageBuilder: (context, state) {
          final droneId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, AddEditDroneScreen(droneId: droneId));
        },
      ),
      GoRoute(
        path: '/admin/drones/details',
        pageBuilder: (context, state) {
          final droneId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, DroneDetailsPage(droneId: droneId));
        },
      ),
      GoRoute(
        path: '/admin/drones/monitor',
        pageBuilder: (context, state) {
          final droneId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, DroneMonitoringPage(droneId: droneId));
        },
      ),
      GoRoute(
        path: '/admin/deliveries/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, DeliveryDetailsScreen(deliveryId: deliveryId));
        },
      ),
      GoRoute(
        path: '/admin/users/details',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return _slide(state, UserDetailsPage(email: email));
        },
      ),
      GoRoute(
        path: '/admin/users/edit',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return _slide(state, EditUserPage(email: email));
        },
      ),
      GoRoute(
        path: '/admin/users/activity',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return _slide(state, UserActivityPage(email: email));
        },
      ),
      GoRoute(
        path: '/admin/missions',
        pageBuilder: (context, state) => _slide(state, const MissionListPage()),
      ),
      GoRoute(
        path: '/admin/missions/details',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _slide(state, MissionDetailsPage(missionId: id));
        },
      ),
      GoRoute(
        path: '/admin/routes/planner',
        pageBuilder: (context, state) => _slide(state, const RoutePlannerPage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones',
        pageBuilder: (context, state) => _slide(state, const NoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/create',
        pageBuilder: (context, state) => _slide(state, const CreateNoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/edit',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          final name = state.uri.queryParameters['name'] ?? '';
          final reason = state.uri.queryParameters['reason'] ?? '';
          return _slide(
            state,
            EditNoFlyZonePage(
              zoneId: id,
              name: name,
              reason: reason,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/reports',
        pageBuilder: (context, state) => _slide(state, const ReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/deliveries',
        pageBuilder: (context, state) => _slide(state, const DeliveryReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/drones',
        pageBuilder: (context, state) => _slide(state, const DroneReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/users',
        pageBuilder: (context, state) => _slide(state, const UserReportsPage()),
      ),

      // ─── Shared ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/shared/about',
        pageBuilder: (context, state) => _slide(state, const AboutPage()),
      ),
      GoRoute(
        path: '/shared/help',
        pageBuilder: (context, state) => _slide(state, const HelpSupportPage()),
      ),
      GoRoute(
        path: '/shared/privacy-policy',
        pageBuilder: (context, state) => _slide(state, const PrivacyPolicyPage()),
      ),
      GoRoute(
        path: '/shared/terms-conditions',
        pageBuilder: (context, state) => _slide(state, const TermsConditionsPage()),
      ),
    ],
  );
});

// Shared page transition builders ─────────────────────────────────────────────

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
