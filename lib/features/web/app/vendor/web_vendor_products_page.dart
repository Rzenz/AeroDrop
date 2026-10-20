import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/product_model.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../web_kit.dart';

/// The canteen's inventory as a table: what is listed, at what price, how
/// much is left, and the edit and delete actions on each row.
class WebVendorProductsPage extends ConsumerStatefulWidget {
  const WebVendorProductsPage({super.key});

  @override
  ConsumerState<WebVendorProductsPage> createState() =>
      _WebVendorProductsPageState();
}

class _WebVendorProductsPageState extends ConsumerState<WebVendorProductsPage> {
  final _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(ProductModel p) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Delete ${p.name}?',
      message: 'It comes off your menu straight away. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    final done = await ref
        .read(vendorProductsProvider.notifier)
        .deleteProduct(p.id);
    if (!mounted) return;
    showNeuSnack(
      context,
      done ? '${p.name} deleted.' : '${p.name} could not be deleted.',
      tone: done ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorProductsProvider);
    final all = state.products;
    final categories = [
      'All',
      ...{for (final p in all) p.category},
    ];
    if (!categories.contains(_category)) _category = 'All';
    final q = _query.trim().toLowerCase();
    final rows = all
        .where(
          (p) =>
              (_category == 'All' || p.category == _category) &&
              (q.isEmpty || p.name.toLowerCase().contains(q)),
        )
        .toList();
    final low = all.where((p) => p.stock > 0 && p.stock <= 3).length;
    final out = all.where((p) => p.stock <= 0).length;
    final compact = WebLayout.isCompact(context);

    Widget stock(ProductModel p) {
      if (p.stock <= 0) {
        return const WebPill(label: 'Sold out', tone: AppColors.danger);
      }
      if (p.stock <= 3) {
        return WebPill(label: '${p.stock} left', tone: AppColors.warning);
      }
      return Text('${p.stock}', style: WebText.label(size: 14));
    }

    Widget body;
    if (state.isLoading && all.isEmpty) {
      body = Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const WebSkeleton(height: 68, radius: 16),
          ],
        ],
      );
    } else if (all.isEmpty) {
      body = WebEmpty(
        icon: Icons.inventory_2_outlined,
        title: 'Your menu is empty',
        message: 'Add the first thing you sell and customers can order it.',
        action: WebButton(
          label: 'Add product',
          icon: Icons.add_rounded,
          onPressed: () => context.push('/vendor/products/add'),
        ),
      );
    } else if (rows.isEmpty) {
      body = const WebEmpty(
        icon: Icons.search_off_rounded,
        title: 'Nothing matches that',
        message: 'Try another category or a shorter search.',
      );
    } else {
      body = WebTable<ProductModel>(
        rows: rows,
        onRowTap: (p) => context.push('/vendor/products/edit?id=${p.id}'),
        columns: [
          WebColumn(
            'Product',
            (p) => Row(
              children: [
                WebThumb(url: p.imageUrl, name: p.name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WebText.label(size: 14.5),
                      ),
                      Text(p.category, style: WebText.body(size: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            flex: 5,
            primary: true,
          ),
          WebColumn(
            'Price',
            (p) => Text(WebText.peso(p.price), style: WebText.label(size: 14)),
            flex: 2,
          ),
          WebColumn('Stock', stock, flex: 2),
          WebColumn(
            'Weight',
            (p) => Text(
              '${(p.weightKg * 1000).round()} g',
              style: WebText.body(size: 13.5),
            ),
            flex: 2,
          ),
          WebColumn(
            'Rating',
            (p) => Text(
              p.hasReviews ? '★ ${p.rating.toStringAsFixed(1)}' : 'New',
              style: WebText.body(size: 13.5),
            ),
            flex: 2,
          ),
        ],
        trailing: (p) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit ${p.name}',
              size: 36,
              onPressed: () => context.push('/vendor/products/edit?id=${p.id}'),
            ),
            const SizedBox(width: 4),
            WebIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete ${p.name}',
              size: 36,
              color: AppColors.readable(AppColors.danger),
              onPressed: () => _delete(p),
            ),
          ],
        ),
      );
    }

    return WebPage(
      title: 'Products',
      subtitle: '${all.length} on your menu',
      onRefresh: () => ref.read(vendorProductsProvider.notifier).loadProducts(),
      actions: [
        WebSearch(
          controller: _search,
          hint: 'Search your menu',
          width: compact ? null : 280,
          onChanged: (v) => setState(() => _query = v),
        ),
        WebButton(
          label: 'Add product',
          icon: Icons.add_rounded,
          onPressed: () => context.push('/vendor/products/add'),
        ),
      ],
      children: [
        WebGrid(
          minTile: 200,
          maxColumns: 3,
          children: [
            WebStat(
              label: 'Listed',
              value: '${all.length}',
              icon: Icons.inventory_2_outlined,
            ),
            WebStat(
              label: 'Running low',
              value: '$low',
              icon: Icons.trending_down_rounded,
              tone: AppColors.warning,
              note: '3 or fewer left',
            ),
            WebStat(
              label: 'Sold out',
              value: '$out',
              icon: Icons.remove_shopping_cart_outlined,
              tone: AppColors.danger,
            ),
          ],
        ),
        if (categories.length > 2)
          WebChips(
            labels: categories,
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
        body,
      ],
    );
  }
}
