enum DeliveryStatus { pending, assigning, inTransit, delivered, cancelled }

class DeliveryModel {
  final String id;
  final String senderName;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddress;
  final String packageName;
  final double packageWeight; // in kg
  final String packageType;
  final DeliveryStatus status;
  final String? droneId;
  final String eta;
  final DateTime createdAt;
  final double progress; // 0.0 to 1.0
  final double? estimatedDistanceKm;
  final double? paymentAmount;
  // Timestamp-based tracking - survives refresh, hot restart, logout
  final DateTime? deliveryStartedAt;
  final int estimatedDeliverySeconds;
  final DateTime? deliveredAt;

  DeliveryModel({
    required this.id,
    required this.senderName,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddress,
    required this.packageName,
    required this.packageWeight,
    required this.packageType,
    required this.status,
    this.droneId,
    required this.eta,
    required this.createdAt,
    required this.progress,
    this.estimatedDistanceKm,
    this.paymentAmount,
    this.deliveryStartedAt,
    this.estimatedDeliverySeconds = 60,
    this.deliveredAt,
  });

  DeliveryModel copyWith({
    String? id,
    String? senderName,
    String? recipientName,
    String? recipientPhone,
    String? deliveryAddress,
    String? packageName,
    double? packageWeight,
    String? packageType,
    DeliveryStatus? status,
    String? droneId,
    String? eta,
    DateTime? createdAt,
    double? progress,
    double? estimatedDistanceKm,
    double? paymentAmount,
    DateTime? deliveryStartedAt,
    int? estimatedDeliverySeconds,
    DateTime? deliveredAt,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      packageName: packageName ?? this.packageName,
      packageWeight: packageWeight ?? this.packageWeight,
      packageType: packageType ?? this.packageType,
      status: status ?? this.status,
      droneId: droneId ?? this.droneId,
      eta: eta ?? this.eta,
      createdAt: createdAt ?? this.createdAt,
      progress: progress ?? this.progress,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      deliveryStartedAt: deliveryStartedAt ?? this.deliveryStartedAt,
      estimatedDeliverySeconds: estimatedDeliverySeconds ?? this.estimatedDeliverySeconds,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}