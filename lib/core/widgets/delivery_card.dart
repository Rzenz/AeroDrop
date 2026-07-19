import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'status_chip.dart';
import 'animated_card.dart';

class DeliveryCard extends ConsumerStatefulWidget {
  final DeliveryModel delivery;
  final VoidCallback? onTap;

  const DeliveryCard({super.key, required this.delivery, this.onTap});

  @override
  ConsumerState<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends ConsumerState<DeliveryCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delivery.status == DeliveryStatus.inTransit) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(DeliveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.delivery.status == DeliveryStatus.inTransit) {
      if (_timer == null) {
        _startTimer();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _displayId {
    if (widget.delivery.id.length <= 12) return widget.delivery.id;
    return 'DEL-${widget.delivery.id.substring(0, 8).toUpperCase()}';
  }

  String _formatTimeRemaining(int totalSeconds) {
    if (totalSeconds <= 0) return 'Arrived';
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return 'Time Remaining: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.delivery.status;
    final isInTransit = status == DeliveryStatus.inTransit;

    double progress = widget.delivery.progress;
    int remainingSeconds = 0;

    if (isInTransit) {
      final startedAt = widget.delivery.deliveryStartedAt;
      if (startedAt != null) {
        final totalSecs = widget.delivery.estimatedDeliverySeconds;
        final elapsed = DateTime.now().difference(startedAt).inSeconds;
        progress = (elapsed / totalSecs).clamp(0.0, 1.0);
        remainingSeconds = (totalSecs - elapsed).clamp(0, totalSecs);
      }
    } else if (status == DeliveryStatus.delivered) {
      progress = 1.0;
    }

    final percentage = (progress * 100).toInt();

    return AnimatedCard(
      onTap: widget.onTap,
      borderGradient: LinearGradient(
        colors: isInTransit
            ? [AppColors.accent, AppColors.primary]
            : [
                AppColors.borderDark,
                AppColors.borderDark.withValues(alpha: 0.4),
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          if (isInTransit)
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayId,
                      style: AppTextStyles.label(
                        fontSize: 11,
                        color: AppColors.primaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip.delivery(status.name),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.delivery.packageName,
                style: AppTextStyles.title(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.delivery.deliveryAddress,
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        color: AppColors.textSecondaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isInTransit) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatTimeRemaining(remainingSeconds),
                        style: AppTextStyles.body(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percentage%',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accent,
                    ),
                    minHeight: 5,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.delivery.packageType,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.delivery.packageWeight} kg',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
