import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cart_model.dart';
import '../../../../core/models/delivery_model.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/delivery_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../dashboard/widgets/dash_kit.dart';
import '../web_kit.dart';

/// The customer's home: what to order, what is in the cart, and whether
/// anything is in the air.
///
/// Three widths, one screen:
/// - From [Dash.panelBreak]: the reference's three columns. The sidebar comes
///   from [UserShell]; this screen draws the centre and the order panel.
/// - From [Dash.sidebarBreak]: the sidebar and the centre; the cart is one
///   tap away on the top bar.
/// - Below that: one column on a phone, with the bottom dock.
class WebDashboardPage extends ConsumerStatefulWidget {
  const WebDashboardPage({super.key});

  @override
  ConsumerState<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends ConsumerState<WebDashboardPage> {
  final _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(productProvider.notifier).loadProducts(),
      ref.read(orderProvider.notifier).loadOrders(),
      ref.read(deliveryProvider.notifier).loadDeliveriesFromSupabase(),
      ref.read(notificationProvider.notifier).loadNotifications(),
      ref.read(vendorProvider.notifier).loadVendors(),
    ]);
  }

  List<ProductModel> _visible(List<ProductModel> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      final inCategory = _category == 'All' || p.category == _category;
      final matches =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.vendorName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return inCategory && matches;
    }).toList();
  }

  void _add(ProductModel p, int inCart) {
    // Never more in the cart than the canteen has on the shelf.
    if (inCart >= p.stock) return;
    cartNotifier.addItem(
      CartItem(
        productId: p.id,
        productName: p.name,
        vendorId: p.vendorId,
        vendorName: p.vendorName,
        imageUrl: p.imageUrl,
        unitPrice: p.price,
        weightKg: p.weightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final withPanel = width >= Dash.panelBreak;
    final withSidebar = width >= Dash.sidebarBreak;

    final user = ref.watch(authProvider).user;
    final productState = ref.watch(productProvider);
    final categories = productState.categories.contains('All')
        ? productState.categories
        : ['All', ...productState.categories];
    if (!categories.contains(_category)) _category = 'All';

    final deliveries = ref.watch(deliveryProvider);
    final active =
        deliveries
            .where(
              (d) =>
                  d.status == DeliveryStatus.inTransit ||
                  d.status == DeliveryStatus.assigning ||
                  d.status == DeliveryStatus.pending,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final activeDelivery = active.isEmpty ? null : active.first;

    final products = _visible(productState.products);
    final gutter = withSidebar ? 32.0 : AppSpacing.pageGutter(context);

    var i = 0;
    Widget reveal(Widget w) => w.dashReveal(context, i++);

    final main = RefreshIndicator(
      color: AppColors.accentFill,
      backgroundColor: AppColors.base,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              withSidebar ? 28 : 12,
              gutter,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                reveal(
                  DashTopBar(
                    controller: _search,
                    onSearch: (v) => setState(() => _query = v),
                    showCart: !withPanel,
                    leading: withSidebar
                        ? null
                        : Row(
                            children: [
                              DashAvatar(
                                name: user?.name,
                                url: user?.avatarUrl,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dashGreeting(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Dash.body(size: 13),
                                    ),
                                    Text(
                                      (user?.name ?? '')
                                          .trim()
                                          .split(' ')
                                          .first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Dash.title(size: 19),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: withSidebar ? 28 : 20),
                reveal(
                  DashBanner(
                    compact: !withSidebar,
                    onBrowse: () => context.go('/user/shop'),
                  ),
                ),
                if (!withSidebar) ...[
                  const SizedBox(height: 14),
                  reveal(const DashWeatherCard(compact: true)),
                ],
                if (!withPanel && activeDelivery != null) ...[
                  const SizedBox(height: 14),
                  reveal(DashDeliveryCard(delivery: activeDelivery)),
                ],
                SizedBox(height: withSidebar ? 32 : 26),
                reveal(
                  Row(
                    children: [
                      Expanded(
                        child: Text('Categories', style: Dash.display(22)),
                      ),
                      DashTextLink(
                        label: 'Open the shop',
                        onTap: () => context.go('/user/shop'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                reveal(
                  WebChips(
                    labels: categories,
                    selected: _category,
                    onSelected: (c) => setState(() => _category = c),
                  ),
                ),
                const SizedBox(height: 22),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              0,
              gutter,
              withSidebar ? 40 : AppSpacing.dockClearance(context),
            ),
            sliver: SliverToBoxAdapter(
              child: _ProductGrid(
                products: products,
                loading:
                    productState.isLoading && productState.products.isEmpty,
                filtered: _query.isNotEmpty || _category != 'All',
                onClearFilters: () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _category = 'All';
                  });
                },
                onOpen: (p) => context.push('/user/products/${p.id}'),
                onAdd: _add,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        bottom: false,
        child: withPanel
            ? Row(
                children: [
                  Expanded(child: main),
                  DashOrderPanel(activeDelivery: activeDelivery),
                ],
              )
            : main,
      ),
    );
  }
}

/// The food grid. Columns come from the width — about 220px each — and every
/// card is the same height, so rows line up. Loading shows card-shaped
/// placeholders; an empty result says why and offers the way out.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.loading,
    required this.filtered,
    required this.onClearFilters,
    required this.onOpen,
    required this.onAdd,
  });

  final List<ProductModel> products;
  final bool loading;
  final bool filtered;
  final VoidCallback onClearFilters;
  final ValueChanged<ProductModel> onOpen;
  final void Function(ProductModel product, int inCart) onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide enough for two cards' soft shadows to meet without merging.
        const gap = 22.0;
        final columns = (constraints.maxWidth / 220).floor().clamp(2, 5);
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        if (loading) {
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < columns * 2; i++)
                // The card's own height: the mounted photo (8px margin on
                // three sides) and the reserved text block below it.
                NeuSurface(
                  style: NeuStyle.inset,
                  depth: NeuDepth.low,
                  color: AppColors.surfaceSunken,
                  width: cardWidth,
                  height: (cardWidth - 16) * 0.75 + 8 + 146,
                  borderRadius: BorderRadius.circular(22),
                  child: const SizedBox.expand(),
                ),
            ],
          );
        }

        if (products.isEmpty) {
          return NeuSurface(
            style: NeuStyle.inset,
            depth: NeuDepth.low,
            color: AppColors.surfaceSunken,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                Text(
                  filtered ? 'Nothing matches that' : 'No food listed yet',
                  style: Dash.title(size: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  filtered
                      ? 'Try another category or a shorter search.'
                      : 'Campus canteens add their menus here once an '
                            'administrator approves them.',
                  style: Dash.body(size: 13.5),
                  textAlign: TextAlign.center,
                ),
                if (filtered) ...[
                  const SizedBox(height: 10),
                  DashTextLink(label: 'Show everything', onTap: onClearFilters),
                ],
              ],
            ),
          );
        }

        return ValueListenableBuilder<List<CartItem>>(
          valueListenable: cartNotifier,
          builder: (context, cart, _) {
            int countOf(String id) => cart
                .where((c) => c.productId == id)
                .fold<int>(0, (s, c) => s + c.quantity);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < products.length; i++)
                  SizedBox(
                    width: cardWidth,
                    child: DashProductCard(
                      product: products[i],
                      inCart: countOf(products[i].id),
                      onOpen: () => onOpen(products[i]),
                      onAdd: () => onAdd(products[i], countOf(products[i].id)),
                    ).dashReveal(context, 6 + i),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
