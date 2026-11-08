import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_message_model.dart';
import '../models/support_report_model.dart';
import '../services/supabase_service.dart';
import '../utils/image_utils.dart';

/// Matches the CHECK constraints on public.support_messages.
const int kSupportMessageMaxLength = 2000;
const int kSupportMaxAttachments = 3;

/// Private bucket; objects live at `<report_id>/<uuid>.<ext>` because the
/// storage policy reads the first path segment as the report id.
const String kSupportAttachmentsBucket = 'support-attachments';

/// How long a signed attachment URL stays valid, and how long it is reused
/// before being re-signed so a long-open screen never shows an expired one.
const int _signedUrlSeconds = 60 * 60;
const Duration _signedUrlReuse = Duration(minutes: 50);

const _messageColumns =
    'id, report_id, sender_id, message, attachments, created_at, read_at';

final _uuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

class SupportChatState {
  final List<SupportMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? currentUserId;

  const SupportChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isSending = false,
    this.error,
    this.currentUserId,
  });

  /// Messages the other side sent that the current user has not read yet.
  int get unreadCount => messages
      .where((m) => !m.isFrom(currentUserId) && m.readAt == null)
      .length;

  SupportChatState copyWith({
    List<SupportMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return SupportChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      currentUserId: currentUserId,
    );
  }
}

/// One report, for the thread header and its opening entry. Null when the
/// report does not exist or RLS hides it from the current user.
final supportReportProvider = FutureProvider.autoDispose
    .family<SupportReportModel?, String>((ref, reportId) async {
      if (!SupabaseService.isConfigured || !_uuidRegex.hasMatch(reportId)) {
        return null;
      }
      final row = await SupabaseService.client
          .from('support_reports')
          .select()
          .eq('id', reportId)
          .maybeSingle();
      return row == null
          ? null
          : SupportReportModel.fromMap(Map<String, dynamic>.from(row));
    });

/// A user's display name, for labelling the reporter on an admin's screen.
/// Null when the row is unreadable or has no usable name.
final supportUserNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, userId) async {
      if (!SupabaseService.isConfigured || !_uuidRegex.hasMatch(userId)) {
        return null;
      }
      final row = await SupabaseService.client
          .from('users')
          .select('full_name, business_name, email')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      for (final key in ['business_name', 'full_name', 'email']) {
        final value = row[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return null;
    });

/// The current user's own reports, most recently active first, each with its
/// last reply time and unread count.
final mySupportReportsProvider =
    FutureProvider.autoDispose<List<SupportReportModel>>((ref) async {
      if (!SupabaseService.isConfigured) return const [];
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) return const [];

      final res = await SupabaseService.client
          .from('support_reports')
          .select('*, support_messages(created_at, sender_id, read_at)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final reports =
          (res as List)
              .map(
                (e) => SupportReportModel.fromMap(
                  Map<String, dynamic>.from(e),
                  currentUserId: uid,
                ),
              )
              .toList()
            ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
      return reports;
    });

/// Per-report support thread, keyed by reportId.
///
/// Auto-disposed so the realtime channel and the signed-URL cache go away as
/// soon as the thread screen closes.
final supportChatProvider = StateNotifierProvider.autoDispose
    .family<SupportChatNotifier, SupportChatState, String>((ref, reportId) {
      return SupportChatNotifier(reportId);
    });

class SupportChatNotifier extends StateNotifier<SupportChatState> {
  final String reportId;
  RealtimeChannel? _channel;
  bool _markingRead = false;
  final _signedUrls = <String, ({Future<String> url, DateTime signedAt})>{};

  bool get _isValidUuid => _uuidRegex.hasMatch(reportId);

  SupportChatNotifier(this.reportId)
    : super(
        SupportChatState(
          currentUserId: SupabaseService.isConfigured
              ? SupabaseService.client.auth.currentUser?.id
              : null,
        ),
      ) {
    if (!SupabaseService.isConfigured) {
      state = state.copyWith(
        isLoading: false,
        error: 'Support messages are unavailable offline.',
      );
      return;
    }
    if (!_isValidUuid) {
      state = state.copyWith(isLoading: false, error: 'Invalid report.');
      return;
    }
    loadMessages();
    _subscribeRealtime();
  }

  Future<void> loadMessages() async {
    if (!SupabaseService.isConfigured || !_isValidUuid) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final res = await SupabaseService.client
          .from('support_messages')
          .select(_messageColumns)
          .eq('report_id', reportId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      final loaded = (res as List)
          .map((e) => SupportMessageModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(
        messages: _mergeSorted(loaded, state.messages),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('loadMessages error for support report $reportId: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, error: _describe(e));
      }
    }
  }

  void _subscribeRealtime() {
    _unsubscribeRealtime();

    try {
      _channel = SupabaseService.client
          .channel('support_chat_$reportId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'support_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'report_id',
              value: reportId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (mounted && rec.isNotEmpty) {
                _upsert(SupportMessageModel.fromMap(rec));
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to support chat realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    if (_channel != null) {
      try {
        SupabaseService.client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  /// Sends [text] and up to three [images] as the current user.
  ///
  /// Everything that can be checked locally is checked before any network
  /// call: the image count, the text, and each image's type and size. Images
  /// are then uploaded under `<reportId>/` and one row is inserted carrying
  /// the text and the stored paths. Throws on any failure so the caller can
  /// show it. If the insert fails after uploads succeed, those files are left
  /// unreferenced; they are not retried.
  Future<void> sendMessage(String text, List<XFile> images) async {
    if (images.length > kSupportMaxAttachments) {
      throw ArgumentError(
        'You can attach up to $kSupportMaxAttachments photos per message.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty && images.isEmpty) {
      throw ArgumentError('Write a message or attach a photo.');
    }
    if (trimmed.length > kSupportMessageMaxLength) {
      throw ArgumentError(
        'Message is too long (${trimmed.length}/$kSupportMessageMaxLength characters).',
      );
    }
    if (!SupabaseService.isConfigured) {
      throw StateError('Support messages are unavailable offline.');
    }
    if (!_isValidUuid) throw StateError('Invalid report.');
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('You need to be signed in to send messages.');
    }

    state = state.copyWith(isSending: true);
    try {
      final validated = <({List<int> bytes, String mime, String ext})>[];
      for (final image in images) {
        final result = await ImageUtils.validateImage(image);
        if (!result.isValid) {
          throw ArgumentError(
            result.errorMessage ??
                'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
          );
        }
        validated.add((
          bytes: await image.readAsBytes(),
          mime: result.mimeType ?? 'image/jpeg',
          ext: result.fileExtension ?? '.jpg',
        ));
      }

      final storage = SupabaseService.client.storage.from(
        kSupportAttachmentsBucket,
      );
      final paths = <String>[];
      for (final image in validated) {
        final path = '$reportId/${_uuidV4()}${image.ext}';
        await storage.uploadBinary(
          path,
          Uint8List.fromList(image.bytes),
          fileOptions: FileOptions(contentType: image.mime),
        );
        paths.add(path);
      }

      final row = await SupabaseService.client
          .from('support_messages')
          .insert({
            'report_id': reportId,
            'sender_id': uid,
            'message': trimmed,
            'attachments': paths,
          })
          .select(_messageColumns)
          .single();
      if (mounted) _upsert(SupportMessageModel.fromMap(row));
    } finally {
      if (mounted) state = state.copyWith(isSending: false);
    }
  }

  /// A signed URL for an attachment [path]. Reused for the notifier's
  /// lifetime, so rebuilding the list does not re-sign, and re-signed only
  /// when the cached URL is close to expiring. A failed signing is dropped
  /// from the cache so a retry asks again.
  Future<String> signedUrlFor(String path) {
    final cached = _signedUrls[path];
    if (cached != null &&
        DateTime.now().difference(cached.signedAt) < _signedUrlReuse) {
      return cached.url;
    }
    final future = SupabaseService.client.storage
        .from(kSupportAttachmentsBucket)
        .createSignedUrl(path, _signedUrlSeconds);
    _signedUrls[path] = (url: future, signedAt: DateTime.now());
    future.catchError((Object e) {
      _signedUrls.remove(path);
      return '';
    });
    return future;
  }

  /// Marks every message the other side sent as read, server side, and clears
  /// the matching bell notifications.
  ///
  /// Only the messages known at call time are flipped locally, so a message
  /// that arrives while the RPC is in flight still counts as unread.
  Future<void> markRead() async {
    if (!SupabaseService.isConfigured || !_isValidUuid || _markingRead) return;
    _markingRead = true;
    final pendingIds = state.messages
        .where((m) => !m.isFrom(state.currentUserId) && m.readAt == null)
        .map((m) => m.id)
        .toSet();

    try {
      await SupabaseService.client.rpc(
        'mark_support_messages_read',
        params: {'p_report_id': reportId},
      );
      if (!mounted) return;
      final now = DateTime.now();
      state = state.copyWith(
        messages: state.messages
            .map((m) => pendingIds.contains(m.id) ? m.markedRead(now) : m)
            .toList(),
      );
    } catch (e) {
      debugPrint('mark_support_messages_read error for report $reportId: $e');
    } finally {
      _markingRead = false;
    }
  }

  void _upsert(SupportMessageModel msg) {
    if (msg.id.isEmpty) return;
    state = state.copyWith(messages: _mergeSorted([msg], state.messages));
  }

  /// Dedupes by id (a sent message arrives both from the insert response and
  /// from realtime) and keeps created_at ascending order.
  @visibleForTesting
  static List<SupportMessageModel> mergeSorted(
    List<SupportMessageModel> incoming,
    List<SupportMessageModel> existing,
  ) => _mergeSorted(incoming, existing);

  static List<SupportMessageModel> _mergeSorted(
    List<SupportMessageModel> incoming,
    List<SupportMessageModel> existing,
  ) {
    final byId = <String, SupportMessageModel>{
      for (final m in existing) m.id: m,
    };
    for (final m in incoming) {
      final prev = byId[m.id];
      // Keep a locally-applied read receipt if the incoming copy predates it.
      byId[m.id] = (prev?.readAt != null && m.readAt == null) ? prev! : m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  /// A random (version 4) UUID for an attachment's file name.
  static String _uuidV4() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _describe(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }
}
