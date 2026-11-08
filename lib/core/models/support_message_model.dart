/// One reply on a support report (public.support_messages).
///
/// Messages are immutable once sent: there is no copyWith for editing content,
/// only [markedRead] for reflecting a read receipt locally.
class SupportMessageModel {
  final String id;
  final String reportId;
  final String senderId;

  /// May be empty when the message carries only attachments.
  final String message;

  /// Storage paths in the private support-attachments bucket, at most three.
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime? readAt;

  const SupportMessageModel({
    required this.id,
    required this.reportId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.attachments = const [],
    this.readAt,
  });

  bool get isRead => readAt != null;

  bool isFrom(String? userId) =>
      userId != null && userId.isNotEmpty && senderId == userId;

  SupportMessageModel markedRead(DateTime at) => SupportMessageModel(
    id: id,
    reportId: reportId,
    senderId: senderId,
    message: message,
    attachments: attachments,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );

  factory SupportMessageModel.fromMap(Map<String, dynamic> map) {
    final rawAttachments = map['attachments'];
    return SupportMessageModel(
      id: map['id']?.toString() ?? '',
      reportId: map['report_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      attachments: rawAttachments is List
          ? rawAttachments
                .map((e) => e?.toString() ?? '')
                .where((p) => p.isNotEmpty)
                .toList()
          : const [],
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
