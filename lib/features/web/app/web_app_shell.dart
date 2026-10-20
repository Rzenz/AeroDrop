import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/cart_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/delivery_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/logout_helper.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/wide_shell.dart';
import '../../dashboard/widgets/dash_kit.dart';
import 'web_kit.dart';

/// Which part of the app a location belongs to.
enum AppArea { customer, vendor, admin, other }

AppArea areaOf(String location) {
  if (location.startsWith('/user')) return AppArea.customer;
  if (location.startsWith('/vendor')) return AppArea.vendor;
  if (location.startsWith('/admin')) return AppArea.admin;
  return AppArea.other;
}

/// Marks a subtree as already inside the shell, so a page inside a shell
/// route does not draw a second sidebar.
class _InShell extends InheritedWidget {
  const _InShell({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_InShell>() != null;

  @override
  bool updateShouldNotify(_InShell oldWidget) => false;
}

/// The website's chrome around a signed-in page.
///
/// The destinations are the app's own, role by role — the website and the
/// app navigate the same way — but the chrome is a website's: a sidebar on a
/// desktop window, and on a phone browser a top bar whose menu slides the
/// same sidebar in. No bottom dock; that is a thumb control for the app.
///
/// Used by the three role shells for their tabs and by the router for the
/// pages pushed over them (cart, checkout, a single order …).
class WebAppShell extends ConsumerWidget {
  const WebAppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var area = areaOf(location);
    // Help, policies and the like belong to every role: they open in the
    // chrome of whoever is signed in, and bare for a visitor.
    if (area == AppArea.other && location.startsWith('/shared')) {
      final user = ref.watch(authProvider).user;
      if (user != null) {
        area = user.isAdmin
            ? AppArea.admin
            : (user.isVendor ? AppArea.vendor : AppArea.customer);
      }
    }
    if (_InShell.of(context) || area == AppArea.other) return child;

    final sidebar = switch (area) {
      AppArea.customer => CustomerSidebar(location: location),
      AppArea.vendor => VendorSidebar(location: location),
      _ => AdminSidebar(location: location),
    };

    if (WebLayout.isWide(context)) {
      return _InShell(
        child: Scaffold(
          backgroundColor: AppColors.base,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sidebar,
              Expanded(child: ClipRect(child: child)),
            ],
          ),
        ),
      );
    }

    return _InShell(
      child: Scaffold(
        backgroundColor: AppColors.base,
        drawer: Drawer(
          width: WideLayout.sidebarWidth + 16,
          backgroundColor: AppColors.base,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          ),
          child: sidebar,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(area: area),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// The phone browser's bar: menu, wordmark, and the two things worth one
/// tap from anywhere — the cart (customers) and notifications.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.area});

  final AppArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final home = switch (area) {
      AppArea.vendor => '/vendor',
      AppArea.admin => '/admin',
      _ => '/user',
    };
    final alerts = switch (area) {
      AppArea.vendor => '/vendor/notifications',
      AppArea.admin => '/admin/notifications',
      _ => '/user/notifications',
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.base,
        boxShadow: [
          BoxShadow(
            color: AppColors.neuShadow.withValues(alpha: 0.55),
            offset: const Offset(0, 6),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Builder(
                  builder: (context) => WebIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Menu',
                    size: 40,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    link: true,
                    label: 'AeroDrop home',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => context.go(home),
                      child: Row(
                        children: [
                          const BrandMark(size: 28, elevated: false),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'AeroDrop',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WebText.title(size: 17),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (area == AppArea.customer)
                  ValueListenableBuilder<List<CartItem>>(
                    valueListenable: cartNotifier,
                    builder: (context, cart, _) => WebIconButton(
                      icon: Icons.shopping_bag_outlined,
                      tooltip: 'Cart',
                      size: 40,
                      count: cart.fold<int>(0, (s, i) => s + i.quantity),
                      onPressed: () => context.push('/user/cart'),
                    ),
                  ),
                WebIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  size: 40,
                  count: unread,
                  onPressed: () => context.push(alerts),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _navigate(BuildContext context, WideNavEntry e) {
  // In the phone browser's drawer, close it first.
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold?.isDrawerOpen ?? false) Navigator.of(context).pop();
  if (e.push) {
    context.push(e.route);
  } else {
    context.go(e.route);
  }
}

class CustomerSidebar extends ConsumerWidget {
  const CustomerSidebar({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider);
    final activeOrders = ref.watch(customerActiveOrdersCountProvider);
    final first = (user?.name ?? '').trim().split(' ').first;

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) => WideSidebar(
        location: location,
        homeRoute: '/user',
        name: first.isEmpty ? 'Welcome' : first,
        subtitle: dashGreeting(),
        avatarUrl: user?.avatarUrl,
        // The app's dock — Home, Shop, Cart, Orders, Profile — plus the two
        // it reaches from its header: tracking and notifications.
        entries: [
          const WideNavEntry(
            'Dashboard',
            Icons.space_dashboard_outlined,
            '/user',
            exact: true,
          ),
          const WideNavEntry('Shop', Icons.storefront_outlined, '/user/shop'),
          WideNavEntry(
            'Cart',
            Icons.shopping_bag_outlined,
            '/user/cart',
            badge: cart.fold<int>(0, (s, i) => s + i.quantity),
            push: true,
          ),
          WideNavEntry(
            'Orders',
            Icons.receipt_long_outlined,
            '/user/orders',
            badge: activeOrders,
          ),
          const WideNavEntry('Track', Icons.map_outlined, '/user/track'),
          WideNavEntry(
            'Notifications',
            Icons.notifications_none_rounded,
            '/user/notifications',
            badge: unread,
          ),
          const WideNavEntry(
            'Profile',
            Icons.person_outline_rounded,
            '/user/profile',
          ),
        ],
        secondary: const [
          WideNavEntry(
            'Settings',
            Icons.settings_outlined,
            '/user/settings',
            push: true,
          ),
        ],
        onNavigate: (e) => _navigate(context, e),
        onSignOut: () => showLogoutConfirmation(context, ref),
        footer: const DashWeatherCard(),
      ),
    );
  }
}

class VendorSidebar extends ConsumerWidget {
  const VendorSidebar({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider);
    final waiting = ref.watch(vendorActionOrdersCountProvider);
    final business = user?.businessName?.trim() ?? '';

    return WideSidebar(
      location: location,
      homeRoute: '/vendor',
      roleLabel: 'Vendor',
      name: business.isEmpty ? (user?.name ?? 'Your store') : business,
      subtitle: business.isEmpty ? 'Vendor account' : (user?.name ?? ''),
      avatarUrl: user?.businessLogoUrl ?? user?.avatarUrl,
      entries: [
        const WideNavEntry(
          'Dashboard',
          Icons.space_dashboard_outlined,
          '/vendor',
          exact: true,
        ),
        const WideNavEntry(
          'Products',
          Icons.inventory_2_outlined,
          '/vendor/products',
        ),
        WideNavEntry(
          'Orders',
          Icons.receipt_long_outlined,
          '/vendor/orders',
          badge: waiting,
        ),
        WideNavEntry(
          'Notifications',
          Icons.notifications_none_rounded,
          '/vendor/notifications',
          badge: unread,
        ),
        const WideNavEntry(
          'Store profile',
          Icons.store_outlined,
          '/vendor/profile',
        ),
      ],
      onNavigate: (e) => _navigate(context, e),
      onSignOut: () => showLogoutConfirmation(context, ref),
      footer: const DashWeatherCard(),
    );
  }
}

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider);
    final pending = ref.watch(pendingDeliveriesCountProvider);

    return WideSidebar(
      location: location,
      homeRoute: '/admin',
      roleLabel: 'Admin',
      name: user?.name ?? 'Administrator',
      subtitle: 'Administrator',
      avatarUrl: user?.avatarUrl,
      // The app's dock (Dashboard, Deliveries, Fleet, Users) followed by the
      // destinations its centre button fans out.
      entries: [
        const WideNavEntry(
          'Command deck',
          Icons.space_dashboard_outlined,
          '/admin',
          exact: true,
        ),
        WideNavEntry(
          'Deliveries',
          Icons.local_shipping_outlined,
          '/admin/deliveries',
          badge: pending,
        ),
        const WideNavEntry(
          'Fleet',
          Icons.flight_takeoff_rounded,
          '/admin/drones',
        ),
        const WideNavEntry(
          'Users',
          Icons.people_outline_rounded,
          '/admin/users',
        ),
        const WideNavEntry(
          'Analytics',
          Icons.bar_chart_rounded,
          '/admin/analytics',
        ),
        const WideNavEntry(
          'Flight boundaries',
          Icons.map_outlined,
          '/admin/routes/no-fly-zones',
        ),
        const WideNavEntry(
          'Weather',
          Icons.wb_sunny_outlined,
          '/admin/weather',
        ),
        const WideNavEntry(
          'Support',
          Icons.support_agent_rounded,
          '/admin/support',
        ),
        const WideNavEntry(
          'System logs',
          Icons.analytics_outlined,
          '/admin/reports',
        ),
      ],
      secondary: [
        WideNavEntry(
          'Notifications',
          Icons.notifications_none_rounded,
          '/admin/notifications',
          badge: unread,
          push: true,
        ),
        const WideNavEntry(
          'Settings',
          Icons.settings_outlined,
          '/admin/settings',
        ),
      ],
      onNavigate: (e) => _navigate(context, e),
      onSignOut: () => showLogoutConfirmation(context, ref),
    );
  }
}
