import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cart_model.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../web_kit.dart';
import 'web_customer_common.dart';

/// The cart as a website shows one: the lines in a table grouped by canteen,
/// and the summary with the way to checkout beside them.
class WebCartPage extends ConsumerWidget {
  const WebCartPage({super.key});

  /// Brings the cart in line with the shelves before checkout — the app's
  /// rule: out-of-stock lines go, prices follow the canteen, quantities cap
  /// at the stock. If anything changed, the reader sees it first.
  bool _reconcile(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    final shelf = ref.read(productProvider).products;
    if (shelf.isEmpty) return true;
    final changed = <String>[];
    for (var i = cart.length - 1; i >= 0; i--) {
      final item = cart[i];
      final match = shelf.where((p) => p.id == item.productId).firstOrNull;
      if (match == null) continue;
      if (!match.isAvailable || match.stock <= 0) {
        cartNotifier.removeItem(item.productId);
        changed.add('${item.productName} (out of stock)');
        continue;
      }
      if (item.unitPrice != match.price) item.unitPrice = match.price;
      if (item.quantity > match.stock) {
        item.quantity = match.stock;
        changed.add('${item.productName} (limited to ${match.stock})');
      }
    }
    if (changed.isEmpty) return true;
    // A new list, so the cart's listeners see the edited prices and caps.
    cartNotifier.value = List.of(cartNotifier.value);
    showNeuSnack(
      context,
      'Cart updated: ${changed.join(', ')}',
      tone: NeuToneKind.info,
    );
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        if (cart.isEmpty) {
          return WebPage(
            title: 'Your cart',
            back: true,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/user/shop'),
            children: [
              WebEmpty(
                icon: Icons.shopping_bag_outlined,
                title: 'Your cart is empty',
                message:
                    'Add something from a campus canteen and it lands here.',
                action: WebButton(
                  label: 'Browse the shop',
                  icon: Icons.storefront_outlined,
                  onPressed: () => context.go('/user/shop'),
                ),
              ),
            ],
          );
        }

        final canteens = cartCanteens(cart);
        final items = cart.fold<int>(0, (s, i) => s + i.quantity);
        final subtotal = cart.fold<double>(0, (s, i) => s + i.subtotal);
        final grams = cartWeightGrams(cart);

        final lines = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final canteen in canteens) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: AppColors.accentText,
                    ),
                    const SizedBox(width: 8),
                    Text(canteen, style: WebText.title(size: 16)),
                  ],
                ),
              ),
              WebTable<CartItem>(
                rows: cart.where((c) => c.vendorName == canteen).toList(),
                columns: [
                  WebColumn(
                    'Item',
                    (c) => Row(
                      children: [
                        WebThumb(url: c.imageUrl, name: c.productName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: WebText.label(size: 14.5),
                          ),
                        ),
                      ],
                    ),
                    flex: 4,
                    primary: true,
                  ),
                  WebColumn(
                    'Price',
                    (c) => Text(
                      WebText.peso(c.unitPrice),
                      style: WebText.body(size: 14),
                    ),
                    flex: 2,
                  ),
                  WebColumn('Quantity', (c) => _Stepper(item: c), flex: 3),
                  WebColumn(
                    'Total',
                    (c) => Text(
                      WebText.peso(c.subtotal),
                      style: WebText.numeric(size: 16),
                    ),
                    flex: 2,
                    align: Alignment.centerRight,
                  ),
                ],
                trailing: (c) => WebButton(
                  label: 'Remove',
                  kind: WebButtonKind.ghost,
                  dense: true,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    cartNotifier.removeItem(c.productId);
                  },
                ),
              ),
              const SizedBox(height: 22),
            ],
          ],
        );

        final summary = WebPanel(
          title: 'Summary',
          depth: NeuDepth.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebKeyValue(
                '$items ${items == 1 ? 'item' : 'items'}',
                WebText.peso(subtotal),
              ),
              WebKeyValue('Drone delivery', 'At checkout'),
              WebKeyValue(
                'Cargo weight',
                '${(grams / 1000).toStringAsFixed(2)} kg of 0.50 kg',
              ),
              const WebGroove(vertical: 12),
              WebKeyValue('Subtotal', WebText.peso(subtotal), emphasis: true),
              const SizedBox(height: 6),
              Text(
                'The delivery fee depends on the building you choose and the '
                'parcel weight, so it is worked out on the next page.',
                style: WebText.body(size: 12.5, color: AppColors.textTertiary),
              ),
              if (canteens.length > 1) ...[
                const SizedBox(height: 14),
                _Notice(
                  'One order goes to one canteen. Your cart has food from '
                  '${canteens.length} — remove the others to check out.',
                ),
              ],
              const SizedBox(height: 18),
              WebButton(
                label: 'Go to checkout',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: canteens.length > 1
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        if (_reconcile(context, ref, cart)) {
                          context.push('/user/checkout');
                        }
                      },
              ),
              const SizedBox(height: 10),
              WebButton(
                label: 'Keep shopping',
                kind: WebButtonKind.secondary,
                expand: true,
                onPressed: () => context.go('/user/shop'),
              ),
            ],
          ),
        );

        return WebPage(
          title: 'Your cart',
          subtitle:
              '$items ${items == 1 ? 'item' : 'items'} from '
              '${canteens.length == 1 ? canteens.first : '${canteens.length} canteens'}',
          back: true,
          onBack: () =>
              context.canPop() ? context.pop() : context.go('/user/shop'),
          actions: [
            WebButton(
              label: 'Clear cart',
              icon: Icons.remove_shopping_cart_outlined,
              kind: WebButtonKind.secondary,
              onPressed: () async {
                final ok = await showNeuConfirm(
                  context,
                  title: 'Clear your cart?',
                  message: 'This removes every item. It cannot be undone.',
                  confirmLabel: 'Clear cart',
                  destructive: true,
                  icon: Icons.remove_shopping_cart_rounded,
                );
                if (ok) cartNotifier.clear();
              },
            ),
          ],
          children: [WebSplit(main: lines, side: summary, sideWidth: 360)],
        );
      },
    );
  }
}

class _Stepper extends ConsumerWidget {
  const _Stepper({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Never more than the canteen has on the shelf, when we know it.
    final stock = ref
        .watch(productProvider)
        .products
        .where((p) => p.id == item.productId)
        .firstOrNull
        ?.stock;
    return WebWell(
      padding: const EdgeInsets.all(3),
      radius: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WebIconButton(
            icon: item.quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            tooltip: item.quantity <= 1 ? 'Remove' : 'One fewer',
            size: 32,
            onPressed: () => cartNotifier.decrement(item.productId),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: WebText.numeric(size: 15),
            ),
          ),
          WebIconButton(
            icon: Icons.add_rounded,
            tooltip: 'One more',
            size: 32,
            onPressed: stock != null && item.quantity >= stock
                ? null
                : () => cartNotifier.increment(item.productId),
          ),
        ],
      ),
    );
  }
}

/// A warning set into the panel, in the warning tone with its icon.
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => WebWell(
    padding: const EdgeInsets.all(14),
    radius: 16,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 19,
          color: AppColors.readable(AppColors.warning),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: WebText.body(size: 13.5, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
