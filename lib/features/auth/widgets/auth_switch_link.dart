import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Already have an account? Sign in" and its opposite number.
///
/// A [Wrap], not a [Row]. Both screens had this as a Row with an unbounded
/// [Text] beside a [TextButton], which overflows the moment the question gets
/// longer or the text scale goes up — the sentence has nowhere to go. Wrapping
/// lets it break onto a second line instead.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: AppTextStyles.body(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: AppTextStyles.label(
              fontSize: 13.5,
              color: AppColors.accentText,
            ),
          ),
        ),
      ],
    );
  }
}
