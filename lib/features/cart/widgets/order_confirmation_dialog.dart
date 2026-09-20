import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/neu_button.dart';

class OrderConfirmationDialog extends StatelessWidget {
  final double totalAmount;
  final String paymentMethodLabel;
  final String dropoffName;

  const OrderConfirmationDialog({
    super.key,
    required this.totalAmount,
    required this.paymentMethodLabel,
    required this.dropoffName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double totalAmount,
    required String paymentMethodLabel,
    required String dropoffName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OrderConfirmationDialog(
        totalAmount: totalAmount,
        paymentMethodLabel: paymentMethodLabel,
        dropoffName: dropoffName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Confirm Your Order?',
              textAlign: TextAlign.center,
              style: AppTextStyles.title(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'Total Amount', value: '₱${totalAmount.toStringAsFixed(2)}', isAccent: true),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'Payment Method', value: paymentMethodLabel),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'Drop-off Pad', value: dropoffName),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Cancellation Rule Warning Callout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can cancel this order only while the vendor is still preparing it. Once it is ready for drone pickup, it can no longer be cancelled.',
                      style: AppTextStyles.caption(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    text: 'Cancel',
                    variant: NeuButtonVariant.neutral,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeuButton(
                    text: 'Confirm & Pay',
                    variant: NeuButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: isAccent ? FontWeight.bold : FontWeight.w600,
            color: isAccent ? AppColors.accent : Colors.white,
          ),
        ),
      ],
    );
  }
}
