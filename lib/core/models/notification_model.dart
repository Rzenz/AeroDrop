class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedDeliveryId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    this.userId = '',
    this.title = '',
    String? message,
    String? body,
    this.type = 'info',
    this.relatedDeliveryId,
    required this.isRead,
    DateTime? createdAt,
    DateTime? timestamp,
    this.readAt,
  })  : message = message ?? body ?? '',
        createdAt = createdAt ?? timestamp ?? DateTime.now();

  // Getters for backward compatibility with existing views
  String get body => message;
  DateTime get timestamp => createdAt;

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? relatedDeliveryId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedDeliveryId: relatedDeliveryId ?? this.relatedDeliveryId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'].toString(),
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'info',
      relatedDeliveryId: map['related_delivery_id']?.toString(),
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())
          : null,
    );
  }
}
