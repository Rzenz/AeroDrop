/// A support report (public.support_reports): the subject, status and owner
/// of a support conversation. The report's own [message] is the thread's
/// opening entry; replies live in public.support_messages.
class SupportReportModel {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String category;

  /// 'open' or 'resolved'.
  final String status;
  final String? adminNotes;
  final String? orderId;
  final String? deliveryId;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// Newest reply, when the query embedded support_messages; null otherwise
  /// or when there are no replies yet.
  final DateTime? lastMessageAt;

  /// Replies from the other side the current user has not read, when the
  /// query embedded support_messages; 0 otherwise.
  final int unreadCount;

  const SupportReportModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.category,
    required this.status,
    required this.createdAt,
    this.adminNotes,
    this.orderId,
    this.deliveryId,
    this.resolvedAt,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  bool get isResolved => status == 'resolved';

  /// Last time anything happened on the thread.
  DateTime get lastActivityAt {
    final last = lastMessageAt;
    return last != null && last.isAfter(createdAt) ? last : createdAt;
  }

  /// The form's category values, as people read them.
  String get categoryLabel => switch (category) {
    'general' => 'General Inquiries',
    'order_issue' => 'Order & Payment Issue',
    'delivery_issue' => 'Drone & Delivery Issue',
    'account' => 'Account & Profile',
    'other' => 'Other Feedback',
    _ => category.isEmpty ? 'General' : category.replaceAll('_', ' '),
  };

  String get statusLabel => isResolved ? 'Resolved' : 'Open';

  /// [currentUserId] decides which embedded replies count as unread.
  factory SupportReportModel.fromMap(
    Map<String, dynamic> map, {
    String? currentUserId,
  }) {
    DateTime? lastMessageAt;
    var unread = 0;
    final replies = map['support_messages'];
    if (replies is List) {
      for (final r in replies.whereType<Map>()) {
        final at = _parse(r['created_at']);
        if (at != null &&
            (lastMessageAt == null || at.isAfter(lastMessageAt))) {
          lastMessageAt = at;
        }
        final sender = r['sender_id']?.toString();
        if (currentUserId != null &&
            sender != null &&
            sender != currentUserId &&
            r['read_at'] == null) {
          unread++;
        }
      }
    }

    final adminNotes = map['admin_notes']?.toString().trim() ?? '';
    final orderId = map['order_id']?.toString() ?? '';
    final deliveryId = map['delivery_id']?.toString() ?? '';
    return SupportReportModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      status: map['status']?.toString().toLowerCase() ?? 'open',
      adminNotes: adminNotes.isEmpty ? null : adminNotes,
      orderId: orderId.isEmpty ? null : orderId,
      deliveryId: deliveryId.isEmpty ? null : deliveryId,
      createdAt: _parse(map['created_at']) ?? DateTime.now(),
      resolvedAt: _parse(map['resolved_at']),
      lastMessageAt: lastMessageAt,
      unreadCount: unread,
    );
  }

  static DateTime? _parse(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
}
