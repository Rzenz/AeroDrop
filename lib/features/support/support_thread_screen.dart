import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/support_report_model.dart';
import '../../core/providers/support_chat_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/neu_scaffold.dart';
import '../../core/widgets/neu_surface.dart';
import '../../core/widgets/neu_text_field.dart';

/// Widest the thread grows on desktop, so bubbles stay readable.
const double _threadMaxWidth = 760;

/// A support report's conversation: the original report as the opening
/// entry, then the replies. Shared by the reporter (customer or vendor) and
/// admins; who is who comes from the report's owner, not the route.
class SupportThreadScreen extends ConsumerStatefulWidget {
  final String reportId;
  const SupportThreadScreen({super.key, required this.reportId});

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _PickedImage {
  final XFile file;
  final Uint8List bytes;
  const _PickedImage(this.file, this.bytes);
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _images = <_PickedImage>[];
  bool _hasText = false;
  bool _picking = false;

  String? get _uid => SupabaseService.isConfigured
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    // A new message from the other side while the screen is open is read
    // immediately; any new message scrolls the thread to the newest entry.
    ref.listenManual<SupportChatState>(supportChatProvider(widget.reportId), (
      prev,
      next,
    ) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        _scrollToNewest();
      }
      if (!next.isLoading && next.unreadCount > 0) _markRead();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead() {
    if (!mounted) return;
    ref.read(supportChatProvider(widget.reportId).notifier).markRead();
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // The list is reversed, so offset 0 is the newest entry.
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickImage() async {
    if (_picking || _images.length >= kSupportMaxAttachments) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final result = await ImageUtils.validateImage(picked);
      if (!mounted) return;
      if (!result.isValid) {
        showNeuSnack(
          context,
          result.errorMessage ?? 'That image cannot be attached.',
          tone: NeuToneKind.warning,
        );
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (_images.length < kSupportMaxAttachments) {
          _images.add(_PickedImage(picked, bytes));
        }
      });
    } catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Could not open your photos: $e',
          tone: NeuToneKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send(SupportReportModel report) async {
    final text = _controller.text;
    final files = _images.map((i) => i.file).toList();
    final reopens = report.isResolved && report.userId == _uid;
    try {
      await ref
          .read(supportChatProvider(widget.reportId).notifier)
          .sendMessage(text, files);
      if (!mounted) return;
      _controller.clear();
      setState(_images.clear);
      // The server reopened the report; refresh the header and banner.
      if (reopens) ref.invalidate(supportReportProvider(widget.reportId));
    } on ArgumentError catch (e) {
      if (mounted) {
        showNeuSnack(context, '${e.message}', tone: NeuToneKind.warning);
      }
    } on StorageException catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Photo upload failed: ${e.message}',
          tone: NeuToneKind.error,
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        showNeuSnack(
          context,
          'Message not sent: ${e.message}',
          tone: NeuToneKind.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showNeuSnack(context, 'Message not sent: $e', tone: NeuToneKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(supportReportProvider(widget.reportId));
    final report = reportAsync.asData?.value;

    final Widget body;
    if (reportAsync.isLoading && report == null) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    } else if (reportAsync.hasError && report == null) {
      body = ErrorStateWidget(
        title: 'Could not load this report',
        message: '${reportAsync.error}',
        onRetry: () => ref.invalidate(supportReportProvider(widget.reportId)),
      );
    } else if (report == null) {
      body = const EmptyStateWidget(
        icon: Icons.support_agent_outlined,
        title: 'Report not found',
        subtitle: 'It may have been removed, or it belongs to someone else.',
      );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _threadMaxWidth),
          child: Column(
            children: [
              Expanded(child: _buildThread(report)),
              _buildBottom(report),
            ],
          ),
        ),
      );
    }

    return NeuScaffold(
      appBar: CustomAppBar(
        title: report?.subject.isNotEmpty == true
            ? report!.subject
            : 'Support report',
        subtitle: report == null
            ? null
            : '${report.categoryLabel} · ${report.statusLabel}',
        action: report == null
            ? null
            : _StatusPill(resolved: report.isResolved),
      ),
      padded: false,
      body: body,
    );
  }

  Widget _buildThread(SupportReportModel report) {
    final chat = ref.watch(supportChatProvider(widget.reportId));
    final uid = _uid;
    final isReporter = report.userId == uid;
    final reporterName = isReporter
        ? 'You'
        : ref.watch(supportUserNameProvider(report.userId)).asData?.value ??
              'Reporter';

    if (chat.isLoading && chat.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (chat.error != null && chat.messages.isEmpty) {
      return ErrorStateWidget(
        title: 'Could not load messages',
        message: chat.error!,
        onRetry: () => ref
            .read(supportChatProvider(widget.reportId).notifier)
            .loadMessages(),
      );
    }

    final messages = chat.messages;
    final notifier = ref.read(supportChatProvider(widget.reportId).notifier);
    final gutter = AppSpacing.pageGutter(context);
    // The original report is the oldest entry, so it sits at the top of the
    // reversed list, after every reply.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.md,
        gutter,
        AppSpacing.md,
      ),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return Column(
            children: [
              _ThreadBubble(
                label: 'Original report · $reporterName',
                text: report.message,
                createdAt: report.createdAt,
                isMine: isReporter,
              ),
              if (messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    isReporter
                        ? 'No replies yet. Support will answer here.'
                        : 'No replies yet.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          );
        }
        final msg = messages[messages.length - 1 - index];
        final isMine = msg.isFrom(uid);
        // Anyone other than the reporter is an admin, and reads as "Support".
        final fromReporter = msg.senderId == report.userId;
        return _ThreadBubble(
          label: isMine ? null : (fromReporter ? reporterName : 'Support'),
          text: msg.message,
          createdAt: msg.createdAt,
          isMine: isMine,
          attachments: msg.attachments,
          signer: notifier.signedUrlFor,
        );
      },
    );
  }

  Widget _buildBottom(SupportReportModel report) {
    final chat = ref.watch(supportChatProvider(widget.reportId));
    final isReporter = report.userId == _uid;
    final gutter = AppSpacing.pageGutter(context);
    final canSend = (_hasText || _images.isNotEmpty) && !chat.isSending;
    final canAttach =
        !chat.isSending && !_picking && _images.length < kSupportMaxAttachments;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.xs,
        gutter,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The composer stays enabled: a reporter's reply reopens the report
          // on the server, deliberately.
          if (report.isResolved) ...[
            _Notice(
              icon: Icons.task_alt_rounded,
              text: isReporter
                  ? 'This report is resolved. Sending a message will reopen it.'
                  : 'This report is resolved. Your reply will not reopen it.',
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (_images.isNotEmpty) ...[
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) => _PreviewThumb(
                  bytes: _images[i].bytes,
                  onRemove: chat.isSending
                      ? null
                      : () => setState(() => _images.removeAt(i)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NeuIconButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: _images.length >= kSupportMaxAttachments
                    ? 'Up to $kSupportMaxAttachments photos'
                    : 'Attach a photo',
                iconColor: canAttach
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
                onPressed: canAttach ? _pickImage : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: NeuTextField(
                  labelText: '',
                  hintText: 'Write a message',
                  controller: _controller,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 4,
                  maxLength: kSupportMessageMaxLength,
                  enabled: !chat.isSending,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              chat.isSending
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  : NeuIconButton(
                      icon: Icons.send_rounded,
                      tooltip: 'Send',
                      iconColor: canSend
                          ? AppColors.accentText
                          : AppColors.textTertiary,
                      onPressed: canSend ? () => _send(report) : null,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool resolved;
  const _StatusPill({required this.resolved});

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        resolved ? 'Resolved' : 'Open',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return NeuPanel(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry in the thread: the original report or a reply.
class _ThreadBubble extends StatelessWidget {
  /// Who sent it; null for the current user's own replies.
  final String? label;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final List<String> attachments;
  final Future<String> Function(String path)? signer;

  const _ThreadBubble({
    required this.label,
    required this.text,
    required this.createdAt,
    required this.isMine,
    this.attachments = const [],
    this.signer,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = (width * 0.75).clamp(0.0, 520.0);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadii.md),
      topRight: const Radius.circular(AppRadii.md),
      bottomLeft: Radius.circular(isMine ? AppRadii.md : AppRadii.xs / 2),
      bottomRight: Radius.circular(isMine ? AppRadii.xs / 2 : AppRadii.md),
    );
    final hasText = text.trim().isNotEmpty;
    final textColor = isMine ? AppColors.onAccentFill : AppColors.textPrimary;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accentFill : AppColors.surfaceRaised,
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText)
              // Full body: it wraps within the bubble's bounded width
              // rather than truncating, so nothing is hidden.
              Text(
                text,
                maxLines: 200,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(fontSize: 14, color: textColor),
              ),
            if (attachments.isNotEmpty && signer != null) ...[
              if (hasText) const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final path in attachments)
                    _AttachmentThumb(path: path, signer: signer!),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (label != null) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          bubble,
          const SizedBox(height: AppSpacing.xxs),
          Text(
            formatSupportTimestamp(createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              fontSize: 10.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same format as the order chat: time today, date and time otherwise.
String formatSupportTimestamp(DateTime dt, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
    return time;
  }
  if (dt.year == today.year) return '${dt.month}/${dt.day} $time';
  return '${dt.month}/${dt.day}/${dt.year} $time';
}

const double _thumbSize = 88;

/// A stored attachment, loaded through a signed URL. Opens full screen.
class _AttachmentThumb extends StatefulWidget {
  final String path;
  final Future<String> Function(String path) signer;
  const _AttachmentThumb({required this.path, required this.signer});

  @override
  State<_AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<_AttachmentThumb> {
  late Future<String> _url = widget.signer(widget.path);

  void _retry() => setState(() => _url = widget.signer(widget.path));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: _thumbSize,
        height: _thumbSize,
        child: FutureBuilder<String>(
          future: _url,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _ThumbPlaceholder(loading: true);
            }
            final url = snap.data ?? '';
            if (snap.hasError || url.isEmpty) {
              return _ThumbPlaceholder(onRetry: _retry);
            }
            return GestureDetector(
              onTap: () => _openFullScreen(context, url),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const _ThumbPlaceholder(loading: true),
                errorBuilder: (_, _, _) => _ThumbPlaceholder(onRetry: _retry),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                    errorBuilder: (_, _, _) => Text(
                      'This photo could not be loaded.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  final bool loading;
  final VoidCallback? onRetry;
  const _ThumbPlaceholder({this.loading = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSunken,
      child: InkWell(
        onTap: onRetry,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Tooltip(
                  message: 'Could not load. Tap to retry.',
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A picked image waiting to be sent, with a remove button.
class _PreviewThumb extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback? onRemove;
  const _PreviewThumb({required this.bytes, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                      semanticLabel: 'Remove photo',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
