import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/review_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/neu_button.dart';
import '../../../core/widgets/neu_feedback.dart';

class OrderReviewDialog extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderReviewDialog({
    super.key,
    required this.order,
  });

  static Future<bool?> show(BuildContext context, {required OrderModel order}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OrderReviewDialog(order: order),
    );
  }

  @override
  ConsumerState<OrderReviewDialog> createState() => _OrderReviewDialogState();
}

class _OrderReviewDialogState extends ConsumerState<OrderReviewDialog> {
  int? _storeRating;
  late final TextEditingController _storeCommentController;
  final Map<String, int> _productRatings = {};
  final Map<String, TextEditingController> _productCommentControllers = {};

  bool _submitting = false;
  bool _initializedFromExisting = false;

  @override
  void initState() {
    super.initState();
    _storeCommentController = TextEditingController();
    for (final item in widget.order.items) {
      _productCommentControllers[item.productId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _storeCommentController.dispose();
    for (final c in _productCommentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initExistingReviews(Map<String, dynamic>? data) {
    if (_initializedFromExisting || data == null) return;
    _initializedFromExisting = true;

    final store = data['store'] as Map<String, dynamic>?;
    if (store != null) {
      _storeRating = (store['rating'] as num?)?.toInt();
      if (store['comment'] != null) {
        _storeCommentController.text = store['comment'].toString();
      }
    }

    final products = data['products'] as List?;
    if (products != null) {
      for (final p in products) {
        final pMap = p as Map<String, dynamic>;
        final pId = pMap['product_id']?.toString();
        if (pId != null) {
          _productRatings[pId] = (pMap['rating'] as num?)?.toInt() ?? 5;
          if (pMap['comment'] != null && _productCommentControllers.containsKey(pId)) {
            _productCommentControllers[pId]!.text = pMap['comment'].toString();
          }
        }
      }
    }
  }

  Future<void> _submit() async {
    if (_storeRating == null && _productRatings.isEmpty) {
      showNeuSnack(context, 'Please select at least a store or product rating.', tone: NeuToneKind.warning);
      return;
    }

    setState(() => _submitting = true);

    final productReviewInputs = <ProductReviewInput>[];
    for (final entry in _productRatings.entries) {
      final comment = _productCommentControllers[entry.key]?.text;
      productReviewInputs.add(ProductReviewInput(
        productId: entry.key,
        rating: entry.value,
        comment: comment,
      ));
    }

    final success = await ReviewService.submitOrderReviews(
      orderId: widget.order.id,
      storeRating: _storeRating,
      storeComment: _storeCommentController.text,
      productReviews: productReviewInputs,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ref.invalidate(vendorRatingsSummaryProvider(widget.order.vendorId));
      ref.invalidate(vendorReviewsProvider(widget.order.vendorId));
      for (final item in widget.order.items) {
        ref.invalidate(productRatingsSummaryProvider(item.productId));
        ref.invalidate(productReviewsProvider(item.productId));
      }
      ref.invalidate(existingOrderReviewProvider(widget.order.id));

      Navigator.of(context).pop(true);
      showNeuSnack(context, 'Thank you! Your review has been submitted.', tone: NeuToneKind.success);
    } else {
      showNeuSnack(context, 'Failed to submit review. Please try again.', tone: NeuToneKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingAsync = ref.watch(existingOrderReviewProvider(widget.order.id));

    existingAsync.whenData((data) {
      if (!_initializedFromExisting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _initExistingReviews(data));
        });
      }
    });

    final vendorName = widget.order.vendorName.isNotEmpty ? widget.order.vendorName : 'Store';

    return Dialog(
      backgroundColor: AppColors.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded, color: AppColors.warning, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rate Your Order',
                          style: AppTextStyles.title(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Order #${widget.order.id.length >= 8 ? widget.order.id.substring(0, 8) : widget.order.id}',
                          style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── STORE REVIEW SECTION ─────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Store: $vendorName',
                      style: AppTextStyles.subHead(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildStarSelector(
                      currentRating: _storeRating ?? 0,
                      onChanged: (val) => setState(() => _storeRating = val),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _storeCommentController,
                      maxLines: 2,
                      maxLength: 300,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Share your feedback for $vendorName (optional)...',
                        hintStyle: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.bgDark,
                        counterStyle: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── PRODUCT REVIEWS SECTION ──────────────────────
              if (widget.order.items.isNotEmpty) ...[
                Text(
                  'Rate Individual Products (Optional)',
                  style: AppTextStyles.subHead(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                for (final item in widget.order.items) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: AppTextStyles.body(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        _buildStarSelector(
                          currentRating: _productRatings[item.productId] ?? 0,
                          starSize: 22,
                          onChanged: (val) => setState(() => _productRatings[item.productId] = val),
                        ),
                        if (_productRatings.containsKey(item.productId) && _productRatings[item.productId]! > 0) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _productCommentControllers[item.productId],
                            maxLines: 1,
                            maxLength: 150,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Product comments (optional)...',
                              hintStyle: AppTextStyles.caption(fontSize: 11, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.bgDark,
                              counterStyle: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeuButton(
                      text: 'Maybe Later',
                      variant: NeuButtonVariant.neutral,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeuButton(
                      text: _submitting ? 'Saving...' : 'Submit Review',
                      variant: NeuButtonVariant.primary,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarSelector({
    required int currentRating,
    required ValueChanged<int> onChanged,
    double starSize = 28,
  }) {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= currentRating;
        return InkWell(
          onTap: () => onChanged(starIndex),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFilled ? AppColors.warning : AppColors.textSecondary.withValues(alpha: 0.4),
              size: starSize,
            ),
          ),
        );
      }),
    );
  }
}
