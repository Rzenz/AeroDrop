class ProductModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final double weightKg;
  final String imageUrl;
  final bool isAvailable;
  final double rating;
  final int reviewCount;

  bool get hasReviews => reviewCount > 0;
  String get ratingLabel => hasReviews
      ? '${rating.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})'
      : 'No reviews yet';
  String get shortRatingDisplay =>
      hasReviews ? rating.toStringAsFixed(1) : 'New';

  const ProductModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.weightKg,
    required this.imageUrl,
    required this.isAvailable,
    this.rating = 0.0,
    this.reviewCount = 0,
  });
}
