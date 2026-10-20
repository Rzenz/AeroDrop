import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/web/app/web_app_shell.dart';

import 'auth_guard.dart';
import '../../demo/demo_mode.dart'; // DEMO

import '../../features/auth/splash_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/otp_email_sent_screen.dart';
import '../../features/auth/verification_page.dart';
import '../../features/auth/complete_profile_screen.dart';
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
import '../../features/admin/admin_support_screen.dart';

import '../../features/shared/about_page.dart';
import '../../features/shared/help_support_page.dart';
import '../../features/shared/privacy_policy_page.dart';
import '../../features/shared/terms_conditions_page.dart';

// Marketplace
import '../../features/vendors/vendors_screen.dart';
import '../../features/vendors/vendor_details_screen.dart';
import '../../features/products/product_details_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/cart/checkout_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_details_screen.dart';
import '../../features/orders/receipt_screen.dart';
import '../../features/payment/payment_screen.dart';
import '../../features/payment/online_payment_waiting_screen.dart';

// Vendor
import '../../features/vendor/vendor_shell.dart';
import '../../features/vendor/vendor_dashboard_screen.dart';
import '../../features/vendor/vendor_orders_screen.dart';
import '../../features/vendor/vendor_products_screen.dart';
import '../../features/vendor/add_edit_product_screen.dart';
import '../../features/vendor/vendor_profile_screen.dart';
import '../../features/vendor/vendor_notifications_screen.dart';

// Web marketing site
import '../../features/web/app/customer/web_cart_page.dart';
import '../../features/web/app/customer/web_dashboard_page.dart';
import '../../features/web/app/customer/web_checkout_page.dart';
import '../../features/web/app/customer/web_orders_page.dart';
import '../../features/web/app/customer/web_payment_waiting_page.dart';
import '../../features/web/app/customer/web_product_page.dart';
import '../../features/web/app/customer/web_shop_page.dart';
import '../../features/web/app/customer/web_store_page.dart';
import '../../features/web/app/customer/web_track_page.dart';
import '../../features/web/app/shared/web_account_pages.dart';
import '../../features/web/app/shared/web_notifications_page.dart';
import '../../features/web/app/admin/web_admin_dashboard_page.dart';
import '../../features/web/app/admin/web_admin_deliveries_page.dart';
import '../../features/web/app/admin/web_admin_fleet_page.dart';
import '../../features/web/auth/web_account_screens.dart';
import '../../features/web/auth/web_login_screen.dart';
import '../../features/web/auth/web_otp_email_sent_screen.dart';
import '../../features/web/auth/web_register_screen.dart';
import '../../features/web/auth/web_verification_page.dart';
import '../../features/web/app/admin/web_admin_analytics_page.dart';
import '../../features/web/app/admin/web_admin_logs_page.dart';
import '../../features/web/app/admin/web_admin_settings_page.dart';
import '../../features/web/app/admin/web_admin_support_page.dart';
import '../../features/web/app/admin/web_admin_users_page.dart';
import '../../features/web/app/admin/web_admin_user_page.dart';
import '../../features/web/app/admin/web_admin_delivery_page.dart';
import '../../features/web/app/admin/web_admin_weather_page.dart';
import '../../features/web/app/admin/web_admin_zones_page.dart';
import '../../features/web/app/shared/web_flight_page.dart';
import '../../features/web/app/shared/web_info_pages.dart';
import '../../features/web/app/shared/web_order_page.dart';
import '../../features/web/app/shared/web_receipt_page.dart';
import '../../features/web/app/web_kit.dart';
import '../../features/web/app/vendor/web_product_form_page.dart';
import '../../features/web/app/vendor/web_vendor_dashboard_page.dart';
import '../../features/web/app/vendor/web_vendor_orders_page.dart';
import '../../features/web/app/vendor/web_vendor_products_page.dart';
import '../../features/web/app/vendor/web_vendor_profile_page.dart';
import '../../features/web/landing/landing_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where a signed-out visitor was heading when the guard sent them to sign
/// in — set when the landing page's "Browse Annex" tile sends them to
/// `/user/shop?search=Annex`, say, or its Contacts row to `/shared/help`. Consumed once, on the redirect that would
/// otherwise drop a freshly signed-in student on the dashboard, so the tile
/// they clicked still takes them where it said it would.
///
/// Kept in memory only: a full-page OAuth round trip loses it, and the
/// student lands on the dashboard as before.
String? _pendingUserLocation;

/// True when this page load is the return leg of Google sign-in on the web:
/// Supabase sends the browser back to the site root with `?code=` for the
/// session exchange. Read once, at start-up — the address bar is cleaned
/// up after the exchange.
final bool _returningFromOAuth =
    kIsWeb && Uri.base.queryParameters.containsKey('code');
bool _oauthReturnHandled = false;

/// Destinations a signed-out visitor can be sent to from the landing page —
/// its canteen tiles and its Help and support contact.
bool _isRememberedDestination(String path) =>
    path.startsWith('/user/') || path == '/shared/help';

/// The landing page for a signed-in student: the location they were sent
/// away from, if there was one, otherwise the dashboard.
String _studentHome() {
  final pending = _pendingUserLocation;
  _pendingUserLocation = null;
  return pending ?? '/user';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // The web build lands on the public marketing page; the mobile build
    // goes straight into the app through the splash screen.
    initialLocation: kIsWeb ? '/' : '/splash',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authProvider.notifier).stream,
    ),
    redirect: (context, state) {
      if (demoBypass.value) return null; // DEMO
      // The landing page is public in both directions: a signed-out visitor
      // reads it, and a signed-in one can still reach it from a shared link
      // without being bounced to their dashboard.
      if (state.uri.path == '/') {
        // Back from Google on the web, the browser is on the site root —
        // the one page the guard otherwise leaves alone, so a freshly signed
        // in visitor would be left on the landing page. Once the session is
        // in, send them on exactly once, as the app's own login screen would.
        final auth = ref.read(authProvider);
        final user = auth.user;
        if (_returningFromOAuth &&
            !_oauthReturnHandled &&
            user != null &&
            auth.sessionUnlocked) {
          _oauthReturnHandled = true;
          if (!user.isAdmin &&
              (user.phoneNumber == null || user.phoneNumber!.trim().isEmpty)) {
            return '/complete-profile';
          }
          if (user.isAdmin) return '/admin';
          if (user.isVendor) return '/vendor';
          if (user.isPendingVendor) return '/account-pending';
          return _studentHome();
        }
        return null;
      }

      // The landing page's Sign in links always reach the sign-in form. A
      // visitor who still has a session would otherwise be bounced from
      // /login to their dashboard, so the link looked like it did nothing.
      if (state.uri.path == '/login' &&
          state.uri.queryParameters['from'] == 'landing') {
        return null;
      }

      final authState = ref.read(authProvider);
      final user = authState.user;
      final isLoggingIn =
          state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/email-sent' ||
          state.uri.path == '/onboarding' ||
          state.uri.path == '/welcome' ||
          state.uri.path == '/verification' ||
          state.uri.path == '/complete-profile' ||
          state.uri.path == '/splash';

      if (user == null) {
        if (!isLoggingIn) {
          if (_isRememberedDestination(state.uri.path)) {
            _pendingUserLocation = state.uri.toString();
          }
          return '/welcome';
        }
        return null;
      }

      // Prioritize verification check
      if (authState.requiresVerification && !authState.isVerified) {
        if (state.uri.path != '/verification') {
          return '/verification';
        }
        return null;
      }

      if (!authState.sessionUnlocked) {
        if (!isLoggingIn) {
          if (_isRememberedDestination(state.uri.path)) {
            _pendingUserLocation = state.uri.toString();
          }
          return '/welcome';
        }
        return null;
      }

      // If user profile has no phone number, prompt to complete profile
      final hasNoPhone =
          !user.isAdmin &&
          (user.phoneNumber == null || user.phoneNumber!.trim().isEmpty);
      if (hasNoPhone) {
        if (state.uri.path != '/complete-profile') {
          return '/complete-profile';
        }
        return null;
      }
      if (state.uri.path == '/complete-profile' && !hasNoPhone) {
        if (user.isAdmin || user.isVendor || user.isPendingVendor) {
          _pendingUserLocation = null;
        }
        if (user.isAdmin) return '/admin';
        if (user.isVendor) return '/vendor';
        if (user.isPendingVendor) return '/account-pending';
        return _studentHome();
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
          state.uri.path == '/verification' ||
          state.uri.path == '/complete-profile') {
        if (user.isAdmin || user.isVendor) _pendingUserLocation = null;
        if (user.isAdmin) return '/admin';
        if (user.isVendor) return '/vendor';
        return _studentHome();
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
      // ─── Public web ──────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fade(state, const LandingPage()),
      ),

      // ─── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        redirect: (_, _) => kIsWeb ? '/' : null,
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        redirect: (_, _) => kIsWeb ? '/' : null,
        pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/welcome',
        // The app's welcome screen is a phone's start screen; the website's
        // way in is its sign-in page.
        redirect: (_, _) => kIsWeb ? '/login' : null,
        pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fade(
          state,
          kIsWeb
              ? WebLoginScreen(
                  asVendor: state.uri.queryParameters['role'] == 'vendor',
                )
              : LoginScreen(
                  asVendor: state.uri.queryParameters['role'] == 'vendor',
                ),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb
              ? WebRegisterScreen(
                  asVendor: state.uri.queryParameters['role'] == 'vendor',
                )
              : const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb
              ? const WebForgotPasswordScreen()
              : const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/email-sent',
        pageBuilder: (context, state) {
          final rawExtra = state.extra;
          final extra = rawExtra is Map
              ? rawExtra.map(
                  (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                )
              : <String, String>{};
          final email = extra['email'] ?? '';
          final phone = (extra['phone'] != null && extra['phone']!.isNotEmpty)
              ? extra['phone']
              : null;
          final role = extra['role'];
          final type = extra['type']?.isNotEmpty == true
              ? extra['type']!
              : 'verification';
          final isGoogleOnly = extra['is_google_only'] == 'true';
          return _fade(
            state,
            kIsWeb
                ? WebOtpEmailSentScreen(
                    email: email,
                    phone: phone,
                    role: role,
                    type: type,
                    isGoogleOnly: isGoogleOnly,
                  )
                : OtpEmailSentScreen(
                    email: email,
                    phone: phone,
                    role: role,
                    type: type,
                    isGoogleOnly: isGoogleOnly,
                  ),
          );
        },
      ),
      GoRoute(
        path: '/verification',
        pageBuilder: (context, state) => _fade(
          state,
          kIsWeb ? const WebVerificationPage() : const VerificationPage(),
        ),
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => _fade(
          state,
          kIsWeb
              ? const WebCompleteProfileScreen()
              : const CompleteProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/account-pending',
        pageBuilder: (context, state) => _fade(
          state,
          kIsWeb ? const WebAccountPendingScreen() : const AccountPendingPage(),
        ),
      ),

      // ─── User Shell (Bottom Nav) ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/user',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebDashboardPage() : const UserDashboardScreen(),
            ),
          ),
          // `?search=` arrives from the landing page's canteen tiles.
          GoRoute(
            path: '/user/shop',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? WebShopPage(
                      initialCategory: state.uri.queryParameters['category'],
                      initialSearch: state.uri.queryParameters['search'],
                    )
                  : VendorsScreen(
                      initialCategory: state.uri.queryParameters['category'],
                      initialSearch: state.uri.queryParameters['search'],
                    ),
            ),
          ),
          GoRoute(
            path: '/user/vendors',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? WebShopPage(
                      initialCategory: state.uri.queryParameters['category'],
                      initialSearch: state.uri.queryParameters['search'],
                    )
                  : VendorsScreen(
                      initialCategory: state.uri.queryParameters['category'],
                      initialSearch: state.uri.queryParameters['search'],
                    ),
            ),
          ),
          GoRoute(
            path: '/user/track',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebTrackPage() : const TrackingScreen(),
            ),
          ),
          GoRoute(
            path: '/user/orders',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebOrdersPage() : const OrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/user/notifications',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebNotificationsPage(area: 'user')
                  : const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: '/user/profile',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebProfilePage() : const ProfileScreen(),
            ),
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
          return _slide(
            state,
            kIsWeb
                ? WebStorePage(vendorId: id)
                : VendorDetailsScreen(vendorId: id),
          );
        },
      ),
      GoRoute(
        path: '/user/products/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebProductPage(productId: id)
                : ProductDetailsScreen(productId: id),
          );
        },
      ),
      GoRoute(
        path: '/user/cart',
        pageBuilder: (context, state) =>
            _slide(state, kIsWeb ? const WebCartPage() : const CartScreen()),
      ),
      GoRoute(
        path: '/user/checkout',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebCheckoutPage() : const CheckoutScreen(),
        ),
      ),
      GoRoute(
        path: '/user/receipt',
        pageBuilder: (context, state) => _fade(state, _receipt(state)),
      ),
      GoRoute(
        path: '/user/orders/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebOrderPage(orderId: id)
                : OrderDetailsScreen(orderId: id),
          );
        },
      ),
      GoRoute(
        path: '/user/payment',
        // On the website the order's own page shows its payment status and
        // the way to finish an online payment; the app's screen here only
        // pretends to take one.
        redirect: (context, state) {
          final orderId = state.uri.queryParameters['orderId'];
          if (!kIsWeb) return null;
          return orderId == null || orderId.isEmpty
              ? '/user/orders'
              : '/user/orders/$orderId';
        },
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'];
          return _slide(state, PaymentScreen(orderId: orderId));
        },
      ),
      GoRoute(
        path: '/user/payment-waiting',
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] ?? '';
          final invoiceUrl = state.uri.queryParameters['invoiceUrl'];
          return _slide(
            state,
            kIsWeb
                ? WebPaymentWaitingPage(
                    orderId: orderId,
                    invoiceUrl: invoiceUrl,
                  )
                : OnlinePaymentWaitingScreen(
                    orderId: orderId,
                    initialInvoiceUrl: invoiceUrl,
                  ),
          );
        },
      ),
      GoRoute(
        path: '/user/profile/edit',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebEditProfilePage() : const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/user/profile/change-password',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebChangePasswordPage() : const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: '/user/settings',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebSettingsPage() : const SettingsPage(),
        ),
      ),
      // Delivery summary/success/completed routes removed — replaced by /user/payment
      GoRoute(
        path: '/user/track/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebFlightPage(deliveryId: deliveryId)
                : TrackingDetailsPage(deliveryId: deliveryId),
          );
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
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebVendorDashboardPage()
                  : const VendorDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/orders',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebVendorOrdersPage() : const VendorOrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/products',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebVendorProductsPage()
                  : const VendorProductsScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/profile',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebVendorProfilePage()
                  : const VendorProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor/notifications',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebNotificationsPage(area: 'vendor')
                  : const VendorNotificationsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/vendor/products/add',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebProductFormPage() : const AddEditProductScreen(),
        ),
      ),
      GoRoute(
        path: '/vendor/products/edit',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebProductFormPage(productId: id)
                : AddEditProductScreen(productId: id),
          );
        },
      ),
      GoRoute(
        path: '/vendor/profile/edit',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebEditProfilePage() : const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/vendor/orders/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebOrderPage(orderId: id, vendor: true)
                : OrderDetailsScreen(orderId: id),
          );
        },
      ),
      GoRoute(
        path: '/vendor/receipt',
        pageBuilder: (context, state) => _fade(state, _receipt(state)),
      ),
      GoRoute(
        path: '/vendor/track/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebFlightPage(deliveryId: deliveryId, vendor: true)
                : TrackingDetailsPage(deliveryId: deliveryId),
          );
        },
      ),

      // ─── Admin Shell (Drawer) ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebAdminDashboardPage()
                  : const AdminDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/users',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebAdminUsersPage() : const AdminUsersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/drones',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/deliveries',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebAdminDeliveriesPage()
                  : const AdminDeliveriesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/analytics',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebAdminAnalyticsPage()
                  : const AdminAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb
                  ? const WebAdminSettingsPage()
                  : const AdminSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/weather',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebAdminWeatherPage() : const AdminWeatherScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/support',
            pageBuilder: (context, state) => _fade(
              state,
              kIsWeb ? const WebAdminSupportPage() : const AdminSupportScreen(),
            ),
          ),
        ],
      ),

      // ─── Admin Full-Screen Pushes ────────────────────────────────────────
      GoRoute(
        path: '/admin/drones/add',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/drones/edit',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/drones/details',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/drones/monitor',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/deliveries/details',
        pageBuilder: (context, state) {
          final deliveryId = state.uri.queryParameters['id'] ?? '';
          return _slide(
            state,
            kIsWeb
                ? WebAdminDeliveryPage(deliveryId: deliveryId)
                : DeliveryDetailsScreen(deliveryId: deliveryId),
          );
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
            child: kIsWeb
                ? WebAdminUserPage(userId: userId)
                : AdminUserDetailsScreen(userId: userId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  if (kIsWeb) {
                    return _wideFramed(state, animation, child);
                  }
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
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/missions/details',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminFleetPage() : const AdminDronesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/routes/planner',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminZonesPage() : const NoFlyZonePage(),
        ),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminZonesPage() : const NoFlyZonePage(),
        ),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/create',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminZonesPage() : const NoFlyZonePage(),
        ),
      ),
      GoRoute(
        path: '/admin/routes/no-fly-zones/edit',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminZonesPage() : const NoFlyZonePage(),
        ),
      ),
      GoRoute(
        path: '/admin/reports',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminLogsPage() : const ReportsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/reports/deliveries',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminLogsPage() : const ReportsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/reports/drones',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminLogsPage() : const ReportsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/reports/users',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebAdminLogsPage() : const ReportsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/notifications',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb
              ? const WebNotificationsPage(area: 'admin')
              : const NotificationsScreen(),
        ),
      ),

      // ─── Shared ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/shared/about',
        pageBuilder: (context, state) =>
            _slide(state, kIsWeb ? const WebAboutPage() : const AboutPage()),
      ),
      GoRoute(
        path: '/shared/help',
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'];
          final deliveryId = state.uri.queryParameters['deliveryId'];
          return _slide(
            state,
            kIsWeb
                ? WebHelpPage(orderId: orderId, deliveryId: deliveryId)
                : HelpSupportPage(orderId: orderId, deliveryId: deliveryId),
          );
        },
      ),
      // Any role's password change; the /user one is behind the customer
      // guard, which vendors and administrators are redirected away from.
      GoRoute(
        path: '/shared/change-password',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? const WebChangePasswordPage() : const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: '/shared/privacy-policy',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? WebPolicyPage.privacy : const PrivacyPolicyPage(),
        ),
      ),
      GoRoute(
        path: '/shared/terms-conditions',
        pageBuilder: (context, state) => _slide(
          state,
          kIsWeb ? WebPolicyPage.terms : const TermsConditionsPage(),
        ),
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
      if (kIsWeb) {
        return _wideFramed(state, animation, child);
      }
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
      if (kIsWeb) {
        return _wideFramed(state, animation, child);
      }
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

/// On the website a page sits in its area's chrome (see [WebAppShell]), and
/// only the page itself moves: a full-width slide is a phone gesture, and
/// the sidebar sliding in under an identical sidebar reads as a flicker. The
/// chrome is drawn at once; the page fades up a few pixels.
Widget _wideFramed(
  GoRouterState state,
  Animation<double> animation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return WebAppShell(
    location: state.uri.path,
    child: FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    ),
  );
}

/// The receipt route. Its data travels as route `extra`, which a browser
/// reload drops — the website then points to the order instead of crashing.
Widget _receipt(GoRouterState state) {
  final data = state.extra;
  if (data is ReceiptData) {
    return kIsWeb ? WebReceiptPage(data: data) : ReceiptScreen(data: data);
  }
  final vendor = state.uri.path.startsWith('/vendor');
  return WebPage(
    title: 'Receipt',
    children: [
      WebEmpty(
        icon: Icons.receipt_long_outlined,
        title: 'This receipt is no longer open',
        message: 'Receipts are kept with each order. Open it from the order.',
        action: Builder(
          builder: (context) => WebButton(
            label: 'Go to orders',
            onPressed: () =>
                context.go(vendor ? '/vendor/orders' : '/user/orders'),
          ),
        ),
      ),
    ],
  );
}
