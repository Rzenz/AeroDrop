class ReviewItemModel {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String reviewerName;

  const ReviewItemModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.reviewerName,
  });

  factory ReviewItemModel.fromMap(Map<String, dynamic> map) {
    return ReviewItemModel(
      id: map['id']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      comment: map['comment']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reviewerName: map['reviewer_name']?.toString() ?? 'Anonymous',
    );
  }
}

class RatingSummaryModel {
  final double averageRating;
  final int reviewCount;

  const RatingSummaryModel({
    required this.averageRating,
    required this.reviewCount,
  });

  static const empty = RatingSummaryModel(averageRating: 0.0, reviewCount: 0);

  bool get hasReviews => reviewCount > 0;
  int get totalReviews => reviewCount;

  String get displayRating => hasReviews ? averageRating.toStringAsFixed(1) : 'No reviews yet';
}

class ProductReviewInput {
  final String productId;
  final int rating;
  final String? comment;

  const ProductReviewInput({
    required this.productId,
    required this.rating,
    this.comment,
  });

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'rating': rating,
        if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
      };
}
