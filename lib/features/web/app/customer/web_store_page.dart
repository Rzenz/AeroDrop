import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/product_model.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/review_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../shared/widgets/reviews_list_sheet.dart';
import '../../web_tokens.dart';
import '../web_kit.dart';
import 'web_customer_common.dart';

typedef WebStore = ({VendorViewModel vendor, List<ProductModel> products});

/// One canteen and its active menu — from the loaded catalogue when it is
/// there, otherwise fetched the way the app's store screen fetches it.
final webStoreProvider = FutureProvider.autoDispose.family<WebStore?, String>((
  ref,
  id,
) async {
  final cached = ref
      .watch(vendorProvider)
      .vendors
      .where((v) => v.id == id)
      .firstOrNull;
  if (cached != null) {
    final products = ref
        .watch(productProvider)
        .products
        .where((p) => p.vendorId == id)
        .toList();
    if (products.isNotEmpty || !SupabaseService.isConfigured) {
      return (vendor: cached, products: products);
    }
  }
  if (!SupabaseService.isConfigured) return null;

  final client = SupabaseService.client;
  final vendorRes = await client
      .from('users')
      .select('*, campus_locations(name)')
      .eq('id', id)
      .eq('role', 'vendor')
      .eq('vendor_status', 'active')
      .eq('account_status', 'active')
      .maybeSingle();
  if (vendorRes == null) return null;
  final vendor = VendorViewModel.fromMap(vendorRes);

  final productsRes = await client
      .from('products')
      .select()
      .eq('vendor_id', id)
      .eq('is_active', true);

  final ratings = <String, (double, int)>{};
  try {
    final summaries = await client.from('product_ratings_summary').select();
    for (final s in summaries) {
      final pid = s['product_id']?.toString();
      if (pid == null) continue;
      ratings[pid] = (
        (s['average_rating'] as num?)?.toDouble() ?? 0.0,
        (s['review_count'] as num?)?.toInt() ?? 0,
      );
    }
  } catch (_) {}

  return (
    vendor: vendor,
    products: [
      for (final p in productsRes)
        ProductModel(
          id: p['id'].toString(),
          vendorId: p['vendor_id'].toString(),
          vendorName: vendor.businessName,
          name: p['name'].toString(),
          description: p['description']?.toString() ?? '',
          price: (p['price'] as num).toDouble(),
          stock: (p['stock_quantity'] as num?)?.toInt() ?? 0,
          category: p['category']?.toString() ?? 'Other',
          weightKg: ((p['weight_grams'] as num?) ?? 0) / 1000.0,
          imageUrl: p['image_url']?.toString() ?? '',
          isAvailable: p['is_active'] as bool? ?? true,
          rating: ratings[p['id'].toString()]?.$1 ?? 0,
          reviewCount: ratings[p['id'].toString()]?.$2 ?? 0,
        ),
    ],
  );
});

class WebStorePage extends ConsumerStatefulWidget {
  const WebStorePage({super.key, required this.vendorId});

  final String vendorId;

  @override
  ConsumerState<WebStorePage> createState() => _WebStorePageState();
}

class _WebStorePageState extends ConsumerState<WebStorePage> {
  String _category = 'All';
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/user/shop');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(webStoreProvider(widget.vendorId));
    return async.when(
      loading: () => WebPage(
        title: 'Loading…',
        back: true,
        onBack: _back,
        children: const [
          WebSkeleton(height: 200, radius: 26),
          WebGridSkeleton(),
        ],
      ),
      error: (e, _) => WebPage(
        title: 'Canteen',
        back: true,
        onBack: _back,
        children: [
          WebEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load this canteen',
            message: '$e',
            action: WebButton(
              label: 'Try again',
              kind: WebButtonKind.secondary,
              onPressed: () =>
                  ref.invalidate(webStoreProvider(widget.vendorId)),
            ),
          ),
        ],
      ),
      data: (store) => store == null
          ? WebPage(
              title: 'Canteen',
              back: true,
              onBack: _back,
              children: [
                WebEmpty(
                  icon: Icons.storefront_outlined,
                  title: 'This canteen is not taking orders',
                  message: 'It may be closed for now or no longer on AeroDrop.',
                  action: WebButton(
                    label: 'Back to the shop',
                    kind: WebButtonKind.secondary,
                    onPressed: () => context.go('/user/shop'),
                  ),
                ),
              ],
            )
          : _page(store),
    );
  }

  Widget _page(WebStore store) {
    final v = store.vendor;
    final categories = [
      'All',
      ...{for (final p in store.products) p.category},
    ];
    if (!categories.contains(_category)) _category = 'All';
    final q = _query.trim().toLowerCase();
    final shown = store.products
        .where(
          (p) =>
              (_category == 'All' || p.category == _category) &&
              (q.isEmpty || p.name.toLowerCase().contains(q)),
        )
        .toList();

    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Menu', style: WebText.title(size: 20))),
            Flexible(
              child: WebSearch(
                controller: _search,
                hint: 'Search this menu',
                onChanged: (s) => setState(() => _query = s),
                width: 280,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (categories.length > 2)
          WebChips(
            labels: categories,
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          WebEmpty(
            icon: Icons.fastfood_outlined,
            title: store.products.isEmpty
                ? 'Nothing on the menu yet'
                : 'Nothing matches that',
            message: store.products.isEmpty
                ? '${v.businessName} has not listed any food yet.'
                : 'Try another category or a shorter search.',
          )
        else
          WebProductGrid(products: shown),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebPanel(
          title: 'About',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (v.description.isNotEmpty) ...[
                Text(v.description, style: WebText.body(size: 14.5)),
                const WebGroove(vertical: 12),
              ],
              _Line(Icons.place_outlined, v.building),
              _Line(Icons.person_outline_rounded, v.ownerName),
              if (v.phone.isNotEmpty) _Line(Icons.phone_outlined, v.phone),
              if (v.email.isNotEmpty)
                _Line(Icons.mail_outline_rounded, v.email),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Reviews(vendor: v),
      ],
    );

    return WebPage(
      title: v.businessName,
      subtitle: v.building,
      back: true,
      onBack: _back,
      onRefresh: () async => ref.invalidate(webStoreProvider(widget.vendorId)),
      children: [
        _Banner(vendor: v, count: store.products.length),
        WebSplit(main: menu, side: side, sideWidth: 340, breakpoint: 1040),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.vendor, required this.count});

  final VendorViewModel vendor;
  final int count;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    final sky = WebSky.values[v.businessName.hashCode.abs() % 4];
    final compact = WebLayout.isCompact(context);
    final logo = v.businessLogoUrl;

    final mark = Container(
      width: compact ? 72 : 96,
      height: compact ? 72 : 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: sky.gradient,
        borderRadius: BorderRadius.circular(compact ? 20 : 26),
        boxShadow: NeuPalette.current.shadows(NeuDepth.low),
      ),
      alignment: Alignment.center,
      child: logo == null || logo.isEmpty
          ? Text(
              v.logoInitials,
              style: WebText.display(compact ? 26 : 34, color: sky.ink),
            )
          : Image.network(
              logo,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => Text(
                v.logoInitials,
                style: WebText.display(30, color: sky.ink),
              ),
            ),
    );

    return WebPanel(
      depth: NeuDepth.medium,
      child: Row(
        children: [
          mark,
          SizedBox(width: compact ? 14 : 22),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((v.businessCategory ?? '').isNotEmpty)
                  WebPill(label: v.businessCategory!, tone: AppColors.accent),
                WebPill(
                  label: v.isOpen ? 'Taking orders' : 'Closed',
                  tone: v.isOpen ? AppColors.success : AppColors.danger,
                ),
                Text(
                  '$count ${count == 1 ? 'item' : 'items'} on the menu',
                  style: WebText.body(size: 14),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      v.hasReviews
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 17,
                      color: v.hasReviews
                          ? const Color(0xFFE9A23B)
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      v.ratingLabel,
                      style: WebText.label(
                        size: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: WebText.label(size: 14, weight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.vendor});
  final VendorViewModel vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(vendorRatingsSummaryProvider(vendor.id)).valueOrNull;
    final has = s != null && s.totalReviews > 0;
    return WebPanel(
      title: 'Customer reviews',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                has ? s.averageRating.toStringAsFixed(1) : '–',
                style: WebText.numeric(size: 34),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  has
                      ? 'out of 5 · ${s.totalReviews} ${s.totalReviews == 1 ? 'review' : 'reviews'}'
                      : 'No reviews yet',
                  style: WebText.body(size: 13.5),
                ),
              ),
            ],
          ),
          if (has) ...[
            const SizedBox(height: 14),
            WebButton(
              label: 'Read the reviews',
              kind: WebButtonKind.secondary,
              expand: true,
              onPressed: () => ReviewsListSheet.showForVendor(
                context,
                vendorId: vendor.id,
                vendorName: vendor.businessName,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
