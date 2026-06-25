import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';

import '../../features/dashboard/user_shell.dart';
import '../../features/dashboard/user_dashboard_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/delivery/delivery_history_screen.dart';
import '../../features/delivery/delivery_request_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_drones_screen.dart';
import '../../features/admin/add_edit_drone_screen.dart';
import '../../features/admin/admin_deliveries_screen.dart';
import '../../features/admin/delivery_details_screen.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/admin_settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      // ─── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
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

      // ─── User Full-Screen Pushes (above shell, no bottom nav) ────────────
      GoRoute(
        path: '/user/request',
        pageBuilder: (context, state) => _slide(state, const DeliveryRequestScreen()),
      ),
      GoRoute(
        path: '/user/profile/edit',
        pageBuilder: (context, state) => _slide(state, const EditProfileScreen()),
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

      // ─── Admin Full-Screen Pushes (above shell, no drawer) ───────────────
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
        path: '/admin/deliveries/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, DeliveryDetailsScreen(deliveryId: deliveryId));
        },
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
