import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/vendor_categories.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../web_kit.dart';
import 'web_customer_common.dart';

/// The website's shop: every approved canteen, and everything on their
/// shelves, as browsable grids — the app's Shop tab with the same two views,
/// filters and search, laid out for a browser.
class WebShopPage extends ConsumerStatefulWidget {
  const WebShopPage({super.key, this.initialCategory, this.initialSearch});

  /// From `/user/shop?category=` — a store category.
  final String? initialCategory;

  /// From `/user/shop?search=` — the landing page's canteen tiles.
  final String? initialSearch;

  @override
  ConsumerState<WebShopPage> createState() => _WebShopPageState();
}

class _WebShopPageState extends ConsumerState<WebShopPage> {
  static const _storeCategories = ['All', ...vendorCategories];

  int _tab = 0; // 0 stores, 1 products
  final _search = TextEditingController();
  String _storeQuery = '';
  String _productQuery = '';
  String _storeCategory = 'All';
  String _productCategory = 'All';

  @override
  void initState() {
    super.initState();
    _applyRoute();
  }

  @override
  void didUpdateWidget(covariant WebShopPage old) {
    super.didUpdateWidget(old);
    if (old.initialCategory != widget.initialCategory ||
        old.initialSearch != widget.initialSearch) {
      setState(_applyRoute);
    }
  }

  void _applyRoute() {
    final c = widget.initialCategory;
    if (c != null && _storeCategories.contains(c)) {
      _tab = 0;
      _storeCategory = c;
    }
    final s = widget.initialSearch?.trim();
    if (s != null && s.isNotEmpty) {
      _tab = 0;
      _storeQuery = s;
      _search.text = s;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(vendorProvider.notifier).loadVendors(),
      ref.read(productProvider.notifier).loadProducts(),
    ]);
  }

  void _switchTab(int i) {
    setState(() {
      _tab = i;
      // Each view keeps its own search, so switching back finds it intact.
      _search.text = i == 0 ? _storeQuery : _productQuery;
    });
  }

  bool _storeInCategory(VendorViewModel v) {
    if (_storeCategory == 'All') return true;
    if (_storeCategory == 'Other') {
      return !isPredefinedVendorCategory(v.businessCategory);
    }
    return v.businessCategory?.trim().toLowerCase() ==
        _storeCategory.toLowerCase();
  }

  List<VendorViewModel> _stores(List<VendorViewModel> all) {
    final q = _storeQuery.trim().toLowerCase();
    return all
        .where(
          (v) =>
              _storeInCategory(v) &&
              (q.isEmpty ||
                  v.businessName.toLowerCase().contains(q) ||
                  v.building.toLowerCase().contains(q)),
        )
        .toList();
  }

  List<ProductModel> _products(List<ProductModel> all) {
    final q = _productQuery.trim().toLowerCase();
    return all
        .where(
          (p) =>
              (_productCategory == 'All' || p.category == _productCategory) &&
              (q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.vendorName.toLowerCase().contains(q)),
        )
        .toList();
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      if (_tab == 0) {
        _storeQuery = '';
        _storeCategory = 'All';
      } else {
        _productQuery = '';
        _productCategory = 'All';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(vendorProvider);
    final products = ref.watch(productProvider);
    final stores = _stores(vendors.vendors);
    final items = _products(products.products);
    final productCategories = products.categories.contains('All')
        ? products.categories
        : ['All', ...products.categories];
    final compact = WebLayout.isCompact(context);

    final filtered = _tab == 0
        ? (_storeQuery.isNotEmpty || _storeCategory != 'All')
        : (_productQuery.isNotEmpty || _productCategory != 'All');

    Widget body;
    if (_tab == 0) {
      if (vendors.isLoading && vendors.vendors.isEmpty) {
        body = const WebGridSkeleton(height: 250);
      } else if (vendors.errorMessage != null && vendors.vendors.isEmpty) {
        body = WebEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load the canteens',
          message: vendors.errorMessage!,
          action: WebButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            kind: WebButtonKind.secondary,
            onPressed: () => ref.read(vendorProvider.notifier).loadVendors(),
          ),
        );
      } else if (stores.isEmpty) {
        body = WebEmpty(
          icon: Icons.storefront_outlined,
          title: filtered ? 'No canteen matches that' : 'No canteens yet',
          message: filtered
              ? 'Try another category or a shorter search.'
              : 'Canteens appear here once an administrator approves them.',
          action: filtered
              ? WebButton(
                  label: 'Show every canteen',
                  kind: WebButtonKind.secondary,
                  onPressed: _clearFilters,
                )
              : null,
        );
      } else {
        body = WebGrid(
          minTile: 250,
          maxColumns: 4,
          gap: 22,
          children: [
            for (final v in stores)
              WebStoreCard(
                vendor: v,
                onOpen: () => context.push('/user/vendors/${v.id}'),
              ),
          ],
        );
      }
    } else {
      if (products.isLoading && products.products.isEmpty) {
        body = const WebGridSkeleton();
      } else if (items.isEmpty) {
        body = WebEmpty(
          icon: Icons.fastfood_outlined,
          title: filtered ? 'Nothing matches that' : 'No food listed yet',
          message: filtered
              ? 'Try another category or a shorter search.'
              : 'Canteens add their menus here once they are approved.',
          action: filtered
              ? WebButton(
                  label: 'Show everything',
                  kind: WebButtonKind.secondary,
                  onPressed: _clearFilters,
                )
              : null,
        );
      } else {
        body = WebProductGrid(products: items);
      }
    }

    return WebPage(
      title: 'Shop',
      subtitle: 'Campus canteens and everything on their shelves.',
      onRefresh: _refresh,
      actions: [
        WebSearch(
          controller: _search,
          width: compact ? null : 340,
          hint: _tab == 0
              ? 'Search canteens or buildings'
              : 'Search food or a canteen',
          onChanged: (v) => setState(() {
            if (_tab == 0) {
              _storeQuery = v;
            } else {
              _productQuery = v;
            }
          }),
        ),
      ],
      children: [
        WebTabs(
          labels: const ['Canteens', 'All food'],
          counts: [vendors.vendors.length, products.products.length],
          selected: _tab,
          onSelected: _switchTab,
        ),
        WebChips(
          labels: _tab == 0 ? _storeCategories : productCategories,
          selected: _tab == 0 ? _storeCategory : _productCategory,
          onSelected: (c) => setState(() {
            if (_tab == 0) {
              _storeCategory = c;
            } else {
              _productCategory = c;
            }
          }),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: body),
        ),
      ],
    );
  }
}
