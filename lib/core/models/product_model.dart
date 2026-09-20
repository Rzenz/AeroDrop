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
  });
}
