import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review_model.dart';
import '../services/supabase_service.dart';

final vendorRatingsSummaryProvider =
    FutureProvider.family<RatingSummaryModel, String>((ref, vendorId) async {
  if (!SupabaseService.isConfigured || vendorId.isEmpty) {
    return RatingSummaryModel.empty;
  }
  try {
    final res = await SupabaseService.client
        .from('vendor_ratings_summary')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();

    if (res != null) {
      return RatingSummaryModel(
        averageRating: (res['average_rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (res['review_count'] as num?)?.toInt() ?? 0,
      );
    }
  } catch (e) {
    debugPrint('Error fetching vendor ratings summary: $e');
  }
  return RatingSummaryModel.empty;
});

final productRatingsSummaryProvider =
    FutureProvider.family<RatingSummaryModel, String>((ref, productId) async {
  if (!SupabaseService.isConfigured || productId.isEmpty) {
    return RatingSummaryModel.empty;
  }
  try {
    final res = await SupabaseService.client
        .from('product_ratings_summary')
        .select()
        .eq('product_id', productId)
        .maybeSingle();

    if (res != null) {
      return RatingSummaryModel(
        averageRating: (res['average_rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (res['review_count'] as num?)?.toInt() ?? 0,
      );
    }
  } catch (e) {
    debugPrint('Error fetching product ratings summary: $e');
  }
  return RatingSummaryModel.empty;
});

final vendorReviewsProvider =
    FutureProvider.family<List<ReviewItemModel>, String>((ref, vendorId) async {
  if (!SupabaseService.isConfigured || vendorId.isEmpty) return [];
  try {
    final res = await SupabaseService.client.rpc(
      'get_vendor_reviews',
      params: {'p_vendor_id': vendorId},
    );
    if (res is List) {
      return res
          .map((item) => ReviewItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  } catch (e) {
    debugPrint('Error fetching vendor reviews: $e');
  }
  return [];
});

final productReviewsProvider =
    FutureProvider.family<List<ReviewItemModel>, String>((ref, productId) async {
  if (!SupabaseService.isConfigured || productId.isEmpty) return [];
  try {
    final res = await SupabaseService.client.rpc(
      'get_product_reviews',
      params: {'p_product_id': productId},
    );
    if (res is List) {
      return res
          .map((item) => ReviewItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  } catch (e) {
    debugPrint('Error fetching product reviews: $e');
  }
  return [];
});

final existingOrderReviewProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, orderId) async {
  if (!SupabaseService.isConfigured || orderId.isEmpty) return null;
  try {
    final storeReview = await SupabaseService.client
        .from('store_reviews')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();

    final productReviews = await SupabaseService.client
        .from('product_reviews')
        .select()
        .eq('order_id', orderId);

    return {
      'store': storeReview,
      'products': productReviews,
    };
  } catch (e) {
    debugPrint('Error fetching existing order reviews: $e');
  }
  return null;
});

class ReviewService {
  static Future<bool> submitOrderReviews({
    required String orderId,
    int? storeRating,
    String? storeComment,
    List<ProductReviewInput> productReviews = const [],
  }) async {
    if (!SupabaseService.isConfigured || orderId.isEmpty) return false;
    try {
      final productReviewsPayload =
          productReviews.map((pr) => pr.toMap()).toList();

      final res = await SupabaseService.client.rpc(
        'submit_order_reviews',
        params: {
          'p_order_id': orderId,
          'p_store_rating': storeRating,
          'p_store_comment': storeComment?.trim().isNotEmpty == true
              ? storeComment!.trim()
              : null,
          'p_product_reviews': productReviewsPayload,
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error submitting order reviews: $e');
      return false;
    }
  }
}
