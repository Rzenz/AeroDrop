/// One message in a customer <-> vendor order thread (public.order_messages).
///
/// Messages are immutable once sent: there is no copyWith for editing content,
/// only [markedRead] for reflecting a read receipt locally.
class OrderMessageModel {
  final String id;
  final String orderId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  const OrderMessageModel({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  bool isFrom(String? userId) =>
      userId != null && userId.isNotEmpty && senderId == userId;

  OrderMessageModel markedRead(DateTime at) => OrderMessageModel(
    id: id,
    orderId: orderId,
    senderId: senderId,
    message: message,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );

  factory OrderMessageModel.fromMap(Map<String, dynamic> map) {
    return OrderMessageModel(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())?.toLocal()
          : null,
    );
  }
}
