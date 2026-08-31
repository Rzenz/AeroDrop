import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

import 'auth_guard.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/otp_email_sent_screen.dart';
import '../../features/auth/verification_page.dart';
import '../../features/auth/presentation/pages/account_pending_page.dart';

import '../../features/dashboard/user_shell.dart';
import '../../features/dashboard/user_dashboard_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/tracking/tracking_details_page.dart';
// delivery_history_screen.dart removed — replaced by orders_screen
// delivery_summary/success/completed pages removed — replaced by payment_screen
import '../../features/notifications/notifications_screen.dart';
import '../../features/notifications/notification_details_page.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/change_password_page.dart';
import '../../features/profile/settings_page.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_user_details_screen.dart';
import '../../features/admin/admin_drones_screen.dart';
import '../../features/admin/admin_deliveries_screen.dart';
import '../../features/admin/delivery_details_screen.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/admin_settings_screen.dart';
import '../../features/admin/admin_weather_screen.dart';
import '../../features/admin/no_fly_zone_page.dart';
import '../../features/admin/reports_page.dart';

import '../../features/shared/about_page.dart';
import '../../features/shared/help_support_page.dart';
import '../../features/shared/privacy_policy_page.dart';
import '../../features/shared/terms_conditions_page.dart';

// Marketplace
import '../../features/vendors/vendors_screen.dart';
import '../../features/vendors/vendor_details_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/products/product_details_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/cart/checkout_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_details_screen.dart';
import '../../features/orders/receipt_screen.dart';
import '../../features/payment/payment_screen.dart';

// Vendor
import '../../features/vendor/vendor_shell.dart';
import '../../features/vendor/vendor_dashboard_screen.dart';
import '../../features/vendor/vendor_orders_screen.dart';
import '../../features/vendor/vendor_products_screen.dart';
import '../../features/vendor/add_edit_product_screen.dart';
import '../../features/vendor/vendor_profile_screen.dart';
import '../../features/vendor/vendor_notifications_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final isLoggedIn = user != null;
      final isLoggingIn =
          state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/onboarding' ||
          state.uri.path == '/welcome' ||
          state.uri.path == '/splash';

      if (!isLoggedIn) {
        if (!isLoggingIn) {
          return '/login';
        }
        return null;
      }

      // Prioritize phone verification check
      if (authState.requiresVerification && !authState.isVerified) {
        if (state.uri.path != '/verification') {
          return '/verification';
        }
        return null;
      }

      // Handle vendor pending state redirection
      final isPending = user.vendorStatus == 'pending';
      if (isPending) {
        if (state.uri.path != '/account-pending') {
          return '/account-pending';
        }
        return null;
      }

      if (isLoggingIn ||
          state.uri.path == '/account-pending' ||
          state.uri.path == '/verification') {
        if (user.isAdmin) return '/admin';
        if (user.isVendor) return '/vendor';
        return '/user';
      }

      final isAdminPath = state.uri.path.startsWith('/admin');
      final isUserPath = state.uri.path.startsWith('/user');
      final isVendorPath = state.uri.path.startsWith('/vendor');

      if (isAdminPath && !user.isAdmin) {
        return user.isVendor ? '/vendor' : '/user';
      }
      if (isUserPath && (user.isAdmin || user.isVendor)) {
        return user.isAdmin ? '/admin' : '/vendor';
      }
      if (isVendorPath && !user.isVendor) {
        return user.isAdmin ? '/admin' : '/user';
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
        path: '/welcome',
        pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fade(
          state,
          LoginScreen(asVendor: state.uri.queryParameters['role'] == 'vendor'),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slide(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            _slide(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/email-sent',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          final email = extra['email'] ?? '';
          final type = extra['type'] ?? 'verification';
          return _fade(state, OtpEmailSentScreen(email: email, type: type));
        },
      ),
      GoRoute(
        path: '/verification',
        pageBuilder: (context, state) => _fade(state, const VerificationPage()),
      ),
      GoRoute(
        path: '/account-pending',
        pageBuilder: (context, state) =>
            _fade(state, const AccountPendingPage()),
      ),

      // ─── User Shell (Bottom Nav) ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/user',
            pageBuilder: (context, state) =>
                _fade(state, const UserDashboardScreen()),
          ),
          GoRoute(
            path: '/user/shop',
            pageBuilder: (context, state) =>
                _fade(state, const ProductsScreen()),
          ),
          GoRoute(
            path: '/user/vendors',
            pageBuilder: (context, state) =>
                _fade(state, const VendorsScreen()),
          ),
          GoRoute(
            path: '/user/track',
            pageBuilder: (context, state) =>
                _fade(state, const TrackingScreen()),
          ),
          GoRoute(
            path: '/user/orders',
            pageBuilder: (context, state) => _fade(state, const OrdersScreen()),
          ),
          GoRoute(
            path: '/user/notifications',
            pageBuilder: (context, state) =>
                _fade(state, const NotificationsScreen()),
          ),
          GoRoute(
            path: '/user/profile',
            pageBuilder: (context, state) =>
                _fade(state, const ProfileScreen()),
          ),
        ],
      ),

      // /user/request → redirect to shop (old concept removed)
      GoRoute(path: '/user/request', redirect: (_, _) => '/user/shop'),
      // /user/history → redirect to orders (old concept removed)
      GoRoute(path: '/user/history', redirect: (_, _) => '/user/orders'),
      // Marketplace push routes
      GoRoute(
        path: '/user/vendors/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(state, VendorDetailsScreen(vendorId: id));
        },
      ),
      GoRoute(
        path: '/user/products/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(state, ProductDetailsScreen(productId: id));
        },
      ),
      GoRoute(
        path: '/user/cart',
        pageBuilder: (context, state) => _slide(state, const CartScreen()),
      ),
      GoRoute(
        path: '/user/checkout',
        pageBuilder: (context, state) => _slide(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: '/user/receipt',
        pageBuilder: (context, state) =>
            _fade(state, ReceiptScreen(data: state.extra! as ReceiptData)),
      ),
      GoRoute(
        path: '/user/orders/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(state, OrderDetailsScreen(orderId: id));
        },
      ),
      GoRoute(
        path: '/user/payment',
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'];
          return _slide(state, PaymentScreen(orderId: orderId));
        },
      ),
      GoRoute(
        path: '/user/profile/edit',
        pageBuilder: (context, state) =>
            _slide(state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/user/profile/change-password',
        pageBuilder: (context, state) =>
            _slide(state, const ChangePasswordPage()),
      ),
      GoRoute(
        path: '/user/settings',
        pageBuilder: (context, state) => _slide(state, const SettingsPage()),
      ),
      // Delivery summary/success/completed routes removed — replaced by /user/payment
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

      // ─── Vendor Shell ────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(
            path: '/vendor',
            pageBuilder: (context, state) =>
                _fade(state, const VendorDashboardScreen()),
          ),
          GoRoute(
            path: '/vendor/orders',
            pageBuilder: (context, state) =>
                _fade(state, const VendorOrdersScreen()),
          ),
          GoRoute(
            path: '/vendor/products',
            pageBuilder: (context, state) =>
                _fade(state, const VendorProductsScreen()),
          ),
          GoRoute(
            path: '/vendor/profile',
            pageBuilder: (context, state) =>
                _fade(state, const VendorProfileScreen()),
          ),
          GoRoute(
            path: '/vendor/notifications',
            pageBuilder: (context, state) =>
                _fade(state, const VendorNotificationsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/vendor/products/add',
        pageBuilder: (context, state) =>
            _slide(state, const AddEditProductScreen()),
      ),
      GoRoute(
        path: '/vendor/products/edit',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _slide(state, AddEditProductScreen(productId: id));
        },
      ),
      GoRoute(
        path: '/vendor/profile/edit',
        pageBuilder: (context, state) =>
            _slide(state, const EditProfileScreen()),
      ),

      // ─── Admin Shell (Drawer) ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) =>
                _fade(state, const AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (context, state) =>
                _fade(state, const AdminUsersScreen()),
          ),
          GoRoute(
            path: '/admin/drones',
            pageBuilder: (context, state) =>
                _fade(state, const AdminDronesScreen()),
          ),
          GoRoute(
            path: '/admin/deliveries',
            pageBuilder: (context, state) =>
                _fade(state, const AdminDeliveriesScreen()),
          ),
          GoRoute(
            path: '/admin/analytics',
            pageBuilder: (context, state) =>
                _fade(state, const AdminAnalyticsScreen()),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) =>
                _fade(state, const AdminSettingsScreen()),
          ),
          GoRoute(
            path: '/admin/weather',
            pageBuilder: (context, state) =>
                _fade(state, const AdminWeatherScreen()),
          ),
        ],
      ),

      // ─── Admin Full-Screen Pushes ────────────────────────────────────────
      GoRoute(
        path: '/admin/drones/add',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/drones/edit',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/drones/details',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/drones/monitor',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/deliveries/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(state, DeliveryDetailsScreen(deliveryId: deliveryId));
        },
      ),
      GoRoute(
        path: '/admin/users/:id',
        name: 'admin-user-details',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['id'];
          if (userId == null || userId.isEmpty) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: const Scaffold(
                backgroundColor: AppColors.bgDark,
                body: Center(
                  child: Text(
                    'Account not found.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) => child,
            );
          }
          return CustomTransitionPage<void>(
            key: ValueKey('admin-user-details-$userId'),
            child: AdminUserDetailsScreen(userId: userId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
        },
      ),
      GoRoute(
        path: '/admin/missions',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/missions/details',
        pageBuilder: (context, state) =>
            _slide(state, const AdminDronesScreen()),
      ),
      GoRoute(
        path: '/admin/routes/planner',
        pageBuilder: (context, state) => _slide(state, const NoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones',
        pageBuilder: (context, state) => _slide(state, const NoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/create',
        pageBuilder: (context, state) => _slide(state, const NoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/edit',
        pageBuilder: (context, state) => _slide(state, const NoFlyZonePage()),
      ),
      GoRoute(
        path: '/admin/reports',
        pageBuilder: (context, state) => _slide(state, const ReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/deliveries',
        pageBuilder: (context, state) => _slide(state, const ReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/drones',
        pageBuilder: (context, state) => _slide(state, const ReportsPage()),
      ),
      GoRoute(
        path: '/admin/reports/users',
        pageBuilder: (context, state) => _slide(state, const ReportsPage()),
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
        pageBuilder: (context, state) =>
            _slide(state, const PrivacyPolicyPage()),
      ),
      GoRoute(
        path: '/shared/terms-conditions',
        pageBuilder: (context, state) =>
            _slide(state, const TermsConditionsPage()),
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
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
