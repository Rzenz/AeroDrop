import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int score = 0;
    if (hasMinLength) score++;
    if (hasUppercase) score++;
    if (hasLowercase) score++;
    if (hasDigits) score++;
    if (hasSpecial) score++;

    Color barColor;
    String strengthText;
    double progress;

    if (score <= 2) {
      barColor = AppColors.danger;
      strengthText = 'Weak';
      progress = 0.33;
    } else if (score <= 4) {
      barColor = AppColors.warning;
      strengthText = 'Medium';
      progress = 0.66;
    } else {
      barColor = AppColors.success;
      strengthText = 'Strong';
      progress = 1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength:',
              style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
            ),
            Text(
              strengthText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderDark,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        _RequirementRow(label: 'Minimum 8 characters', met: hasMinLength),
        const SizedBox(height: 6),
        _RequirementRow(label: 'At least one uppercase letter', met: hasUppercase),
        const SizedBox(height: 6),
        _RequirementRow(label: 'At least one lowercase letter', met: hasLowercase),
        const SizedBox(height: 6),
        _RequirementRow(label: 'At least one number', met: hasDigits),
        const SizedBox(height: 6),
        _RequirementRow(label: 'At least one special character (!@#\$%^&*)', met: hasSpecial),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: met ? AppColors.success : AppColors.textSecondaryDark,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: met ? Colors.white : AppColors.textSecondaryDark,
              decoration: met ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}
