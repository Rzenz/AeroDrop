import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cart_model.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/review_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../shared/widgets/reviews_list_sheet.dart';
import '../../web_tokens.dart';
import '../web_kit.dart';
import 'web_customer_common.dart';

/// A product not in the loaded catalogue — opened from a link — fetched by
/// id, with its vendor's name and rating summary, as the app's product
/// screen does.
final webProductByIdProvider = FutureProvider.autoDispose
    .family<ProductModel?, String>((ref, id) async {
      final cached = ref
          .watch(productProvider)
          .products
          .where((p) => p.id == id)
          .firstOrNull;
      if (cached != null) return cached;
      if (!SupabaseService.isConfigured) return null;

      final client = SupabaseService.client;
      Map<String, dynamic>? res;
      try {
        res = await client
            .from('products')
            .select(
              '*, users!vendor_id(full_name, business_name, role, vendor_status, account_status)',
            )
            .eq('id', id)
            .maybeSingle();
      } catch (_) {
        res = await client.from('products').select().eq('id', id).maybeSingle();
      }
      if (res == null) return null;

      final vendorMap = res['users'] as Map<String, dynamic>?;
      var rating = 0.0;
      var reviews = 0;
      try {
        final summary = await client
            .from('product_ratings_summary')
            .select()
            .eq('product_id', id)
            .maybeSingle();
        if (summary != null) {
          rating = (summary['average_rating'] as num?)?.toDouble() ?? 0.0;
          reviews = (summary['review_count'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      return ProductModel(
        id: res['id'].toString(),
        vendorId: res['vendor_id']?.toString() ?? '',
        vendorName:
            vendorMap?['business_name']?.toString() ??
            vendorMap?['full_name']?.toString() ??
            res['vendor_name']?.toString() ??
            'Campus Vendor',
        name: res['name']?.toString() ?? 'Item',
        description: res['description']?.toString() ?? '',
        price: (res['price'] as num?)?.toDouble() ?? 0.0,
        stock: (res['stock_quantity'] as num?)?.toInt() ?? 0,
        category: res['category']?.toString() ?? 'Other',
        weightKg: ((res['weight_grams'] as num?) ?? 0) / 1000.0,
        imageUrl: res['image_url']?.toString() ?? '',
        isAvailable: res['is_active'] as bool? ?? true,
        rating: rating,
        reviewCount: reviews,
      );
    });

class WebProductPage extends ConsumerStatefulWidget {
  const WebProductPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<WebProductPage> createState() => _WebProductPageState();
}

class _WebProductPageState extends ConsumerState<WebProductPage> {
  int _qty = 1;

  void _add(ProductModel p, int inCart) {
    final room = p.stock - inCart;
    final n = _qty.clamp(0, room);
    for (var i = 0; i < n; i++) {
      webAddToCart(p);
    }
    HapticFeedback.mediumImpact();
    setState(() => _qty = 1);
    showNeuSnack(
      context,
      n == 1
          ? '${p.name} added to your cart'
          : '$n × ${p.name} added to your cart',
      tone: NeuToneKind.success,
      actionLabel: 'View cart',
      onAction: () => context.push('/user/cart'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(webProductByIdProvider(widget.productId));

    return async.when(
      loading: () => const WebPage(
        title: 'Loading…',
        back: true,
        children: [WebSkeleton(height: 420, radius: 24)],
      ),
      error: (e, _) => WebPage(
        title: 'Product',
        back: true,
        children: [
          WebEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load this product',
            message: '$e',
          ),
        ],
      ),
      data: (p) {
        if (p == null) {
          return WebPage(
            title: 'Product',
            back: true,
            children: [
              WebEmpty(
                icon: Icons.inventory_2_outlined,
                title: 'This product is not available',
                message:
                    'It may have been removed, or its canteen is not taking '
                    'orders right now.',
                action: WebButton(
                  label: 'Back to the shop',
                  kind: WebButtonKind.secondary,
                  onPressed: () => context.go('/user/shop'),
                ),
              ),
            ],
          );
        }
        return _page(context, p);
      },
    );
  }

  Widget _page(BuildContext context, ProductModel p) {
    final available = p.isAvailable && p.stock > 0;
    final more = ref
        .watch(productProvider)
        .products
        .where((o) => o.vendorId == p.vendorId && o.id != p.id)
        .take(5)
        .toList();

    final photo = NeuSurface(
      depth: NeuDepth.medium,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: p.imageUrl.isEmpty
              ? _Placeholder(name: p.name)
              : Image.network(
                  p.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _Placeholder(name: p.name),
                ),
        ),
      ),
    );

    final about = WebPanel(
      title: 'About this item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.description.isEmpty ? 'No description provided.' : p.description,
            style: WebText.body(size: 15),
          ),
          const WebGroove(vertical: 14),
          WebKeyValue('Category', p.category),
          WebKeyValue('Weight', '${p.weightKg.toStringAsFixed(2)} kg'),
          WebKeyValue(
            'In stock',
            '${p.stock} ${p.stock == 1 ? 'unit' : 'units'}',
          ),
        ],
      ),
    );

    final buy = ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        final inCart = cart
            .where((c) => c.productId == p.id)
            .fold<int>(0, (s, c) => s + c.quantity);
        final room = p.stock - inCart;
        final qty = _qty.clamp(1, room < 1 ? 1 : room);
        return WebPanel(
          depth: NeuDepth.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      WebText.peso(p.price),
                      style: WebText.numeric(
                        size: 32,
                        color: AppColors.accentText,
                      ),
                    ),
                  ),
                  WebPill(
                    label: available
                        ? (p.stock <= 3 ? 'Only ${p.stock} left' : 'In stock')
                        : 'Sold out',
                    tone: available
                        ? (p.stock <= 3 ? AppColors.warning : AppColors.success)
                        : AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Rating(product: p),
              const WebGroove(vertical: 16),
              Text(
                'Quantity',
                style: WebText.label(size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              _QuantityStepper(
                value: qty,
                max: room < 1 ? 1 : room,
                enabled: available && room > 0,
                onChanged: (v) => setState(() => _qty = v),
              ),
              const SizedBox(height: 18),
              WebButton(
                label: !available
                    ? 'Sold out'
                    : (room <= 0
                          ? 'All in your cart'
                          : 'Add ${qty > 1 ? '$qty ' : ''}to cart · ${WebText.peso(p.price * qty)}'),
                icon: Icons.add_shopping_cart_rounded,
                expand: true,
                onPressed: available && room > 0 ? () => _add(p, inCart) : null,
              ),
              if (inCart > 0) ...[
                const SizedBox(height: 10),
                WebButton(
                  label: 'View cart ($inCart in it)',
                  kind: WebButtonKind.secondary,
                  expand: true,
                  onPressed: () => context.push('/user/cart'),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Flown to your building. The delivery fee is worked out at '
                'checkout from the building and the parcel weight.',
                style: WebText.body(size: 12.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        );
      },
    );

    final seller = WebHoverCard(
      onTap: p.vendorId.isEmpty
          ? null
          : () => context.push('/user/vendors/${p.vendorId}'),
      semanticLabel: 'Sold by ${p.vendorName}',
      child: Row(
        children: [
          WebThumb(url: null, name: p.vendorName, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sold by', style: WebText.body(size: 12.5)),
                Text(
                  p.vendorName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WebText.title(size: 15),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.accentText,
          ),
        ],
      ),
    );

    return WebPage(
      title: p.name,
      subtitle: '${p.category} · ${p.vendorName}',
      back: true,
      onBack: () => context.canPop() ? context.pop() : context.go('/user/shop'),
      children: [
        WebSplit(
          sideWidth: 380,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [photo, const SizedBox(height: 24), about],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [buy, const SizedBox(height: 20), seller],
          ),
        ),
        if (more.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'More from ${p.vendorName}',
              style: WebText.title(size: 19),
            ),
          ),
          WebProductGrid(products: more),
        ],
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final sky = WebSky.values[name.hashCode.abs() % 4];
    return DecoratedBox(
      decoration: BoxDecoration(gradient: sky.gradient),
      child: Center(
        child: Text(
          name.isEmpty ? '·' : name[0].toUpperCase(),
          style: WebText.display(72, color: sky.ink),
        ),
      ),
    );
  }
}

class _Rating extends ConsumerWidget {
  const _Rating({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(productRatingsSummaryProvider(product.id))
        .valueOrNull;
    final has = summary != null && summary.totalReviews > 0;
    final text = has
        ? '${summary.averageRating.toStringAsFixed(1)} · ${summary.totalReviews} ${summary.totalReviews == 1 ? 'review' : 'reviews'}'
        : 'No reviews yet';
    final row = Row(
      children: [
        Icon(
          has ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: has ? const Color(0xFFE9A23B) : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: WebText.label(size: 13.5, color: AppColors.textSecondary),
        ),
        if (has) ...[
          const SizedBox(width: 8),
          Text(
            'Read them',
            style: WebText.label(size: 13.5, color: AppColors.accentText),
          ),
        ],
      ],
    );
    if (!has) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ReviewsListSheet.showForProduct(
          context,
          productId: product.id,
          productName: product.name,
        ),
        child: row,
      ),
    );
  }
}

/// − n + in a well. Never below one or above what is left on the shelf.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: WebWell(
        padding: const EdgeInsets.all(5),
        radius: 18,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'One fewer',
              size: 38,
              onPressed: enabled && value > 1
                  ? () => onChanged(value - 1)
                  : null,
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: WebText.numeric(size: 18),
              ),
            ),
            WebIconButton(
              icon: Icons.add_rounded,
              tooltip: 'One more',
              size: 38,
              onPressed: enabled && value < max
                  ? () => onChanged(value + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
