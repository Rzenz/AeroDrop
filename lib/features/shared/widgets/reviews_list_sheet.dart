import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/review_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ReviewsListSheet extends ConsumerWidget {
  final String title;
  final String? vendorId;
  final String? productId;

  const ReviewsListSheet({
    super.key,
    required this.title,
    this.vendorId,
    this.productId,
  });

  static void show(
    BuildContext context, {
    required String title,
    String? vendorId,
    String? productId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReviewsListSheet(
        title: title,
        vendorId: vendorId,
        productId: productId,
      ),
    );
  }

  static void showForVendor(
    BuildContext context, {
    required String vendorId,
    required String vendorName,
  }) {
    show(
      context,
      title: '$vendorName Reviews',
      vendorId: vendorId,
    );
  }

  static void showForProduct(
    BuildContext context, {
    required String productId,
    required String productName,
  }) {
    show(
      context,
      title: '$productName Reviews',
      productId: productId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ReviewItemModel>> reviewsAsync = vendorId != null
        ? ref.watch(vendorReviewsProvider(vendorId!))
        : productId != null
            ? ref.watch(productReviewsProvider(productId!))
            : const AsyncValue.data([]);

    final AsyncValue<RatingSummaryModel> summaryAsync = vendorId != null
        ? ref.watch(vendorRatingsSummaryProvider(vendorId!))
        : productId != null
            ? ref.watch(productRatingsSummaryProvider(productId!))
            : const AsyncValue.data(RatingSummaryModel.empty);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.title(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        summaryAsync.when(
                          data: (summary) => Text(
                            summary.hasReviews
                                ? '⭐ ${summary.averageRating.toStringAsFixed(1)} • ${summary.reviewCount} ${summary.reviewCount == 1 ? "review" : "reviews"}'
                                : 'No reviews yet',
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Review List
            Expanded(
              child: reviewsAsync.when(
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reviews yet',
                            style: AppTextStyles.subHead(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reviews from delivered orders will appear here.',
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = reviews[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                      child: Text(
                                        r.reviewerName.isNotEmpty ? r.reviewerName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      r.reviewerName,
                                      style: AppTextStyles.body(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: List.generate(5, (sIdx) {
                                    final filled = sIdx < r.rating;
                                    return Icon(
                                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                                      size: 16,
                                      color: filled ? AppColors.warning : AppColors.textSecondary.withValues(alpha: 0.3),
                                    );
                                  }),
                                ),
                              ],
                            ),
                            if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                r.comment!.trim(),
                                style: AppTextStyles.body(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(r.createdAt),
                              style: AppTextStyles.caption(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Failed to load reviews: $e', style: const TextStyle(color: AppColors.danger))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
