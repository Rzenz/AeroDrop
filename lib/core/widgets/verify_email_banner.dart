import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_button.dart';
import 'neu_feedback.dart';
import 'neu_list_tile.dart';
import 'neu_text_field.dart';

/// Shown across the customer and vendor shells until the email is verified,
/// like the website's VerifyEmailBanner. Renders nothing for admins, for a
/// verified account, and before migration 35 adds the column.
class VerifyEmailBanner extends ConsumerWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null || !user.needsEmailVerification) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              // Wraps rather than truncating: a long address must stay whole
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Verify your email to start ordering. ',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: "We'll send a 6-digit code to ${user.email}.",
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: NeuButton(
              text: 'Verify email',
              expand: false,
              height: 40,
              onPressed: () => showVerifyEmailSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile row, like the website's EmailVerificationStatus: "Email verified"
/// with a check, or "Email not verified" with a button that opens the code
/// sheet. Hidden for admins and before migration 35 adds the column.
class EmailVerificationTile extends ConsumerWidget {
  const EmailVerificationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null || user.role == 'admin' || !user.emailVerificationKnown) {
      return const SizedBox.shrink();
    }
    if (user.emailVerifiedAt != null) {
      return const NeuListTile(
        icon: Icons.verified_rounded,
        iconColor: AppColors.success,
        title: 'Email verified',
        showChevron: false,
      );
    }
    return NeuListTile(
      icon: Icons.mark_email_unread_outlined,
      iconColor: AppColors.warning,
      title: 'Email not verified',
      subtitle: 'Verify it to place orders',
      showChevron: false,
      trailing: NeuButton(
        text: 'Verify email',
        expand: false,
        height: 36,
        onPressed: () => showVerifyEmailSheet(context),
      ),
      onTap: () => showVerifyEmailSheet(context),
    );
  }
}

/// Puts the banner above a shell's page. The banner takes the status-bar
/// inset itself and the page below drops its top inset, so the two do not
/// stack into a double gap. Without the banner the page is untouched.
class VerifyEmailBannerFrame extends ConsumerWidget {
  final Widget child;
  const VerifyEmailBannerFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needs =
        ref.watch(authProvider.select((s) => s.user?.needsEmailVerification)) ==
        true;
    if (!needs) return child;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageGutter(context),
              AppSpacing.xs,
              AppSpacing.pageGutter(context),
              0,
            ),
            child: const VerifyEmailBanner(),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Opens the code sheet, which emails a code as it opens. On success shows
/// the confirmation from the screen underneath, once the sheet is gone.
Future<void> showVerifyEmailSheet(BuildContext context) async {
  final verified = await showNeuSheet<bool>(
    context,
    title: 'Verify your email',
    child: const _VerifyEmailSheet(),
  );
  if (verified == true && context.mounted) {
    showNeuSnack(
      context,
      'Email verified. You can now place orders.',
      tone: NeuToneKind.success,
    );
  }
}

class _VerifyEmailSheet extends ConsumerStatefulWidget {
  const _VerifyEmailSheet();

  @override
  ConsumerState<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends ConsumerState<_VerifyEmailSheet> {
  final _code = TextEditingController();
  Timer? _ticker;
  int _cooldown = 0;
  bool _sending = false;
  bool _sent = false;
  bool _verifying = false;
  String? _sendError;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    // One code goes out as the sheet opens, unless one went out less than a
    // minute ago: the cooldown lives in the auth provider, so dismissing and
    // reopening the sheet cannot send again early. That earlier code is still
    // valid, so the sheet just asks for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wait = ref
          .read(authProvider.notifier)
          .verificationCodeCooldownRemaining;
      if (wait > Duration.zero) {
        setState(() => _sent = true);
        _startCooldown();
      } else {
        _send();
      }
    });
  }

  /// Whole seconds left on the provider's cooldown, rounded up.
  int _cooldownLeft() {
    final left = ref
        .read(authProvider.notifier)
        .verificationCodeCooldownRemaining;
    return (left.inMilliseconds / 1000).ceil();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Shows the provider's cooldown counting down; the sheet keeps no clock of
  /// its own.
  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _cooldown = _cooldownLeft());
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldownLeft());
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
      _verifyError = null;
    });
    final notifier = ref.read(authProvider.notifier);
    final ok = await notifier.sendEmailVerificationCode();
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _sent = true;
      } else {
        _sendError =
            ref.read(authProvider).errorMessage ??
            'Could not send the code. Please try again.';
      }
    });
    if (ok) _startCooldown();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _verifyError = 'Enter all 6 digits.');
      return;
    }
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    final ok = await ref
        .read(authProvider.notifier)
        .confirmEmailVerification(code);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _verifying = false;
      _verifyError =
          ref.read(authProvider).errorMessage ??
          'That code did not work. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider.select((s) => s.user?.email)) ?? '';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _sending && !_sent
                      ? 'Sending a 6-digit code to '
                      : 'Enter the 6-digit code we sent to ',
                ),
                TextSpan(
                  text: email,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (_sendError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineError(_sendError!),
          ],
          const SizedBox(height: AppSpacing.md),
          NeuTextField(
            labelText: 'Verification code',
            hintText: '6-digit code',
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !_verifying,
            prefixIcon: Icons.pin_outlined,
          ),
          if (_verifyError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InlineError(_verifyError!),
          ],
          const SizedBox(height: AppSpacing.md),
          NeuButton(
            text: 'Verify email',
            isLoading: _verifying,
            // Usable once a code went out, or to try anyway after a send error
            onPressed: (_sent || _sendError != null) && !_verifying
                ? _verify
                : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: _cooldown > 0 || _sending ? null : _send,
              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
              child: Text(
                _sending
                    ? 'Sending...'
                    : _cooldown > 0
                    ? 'Resend code in ${_cooldown}s'
                    : 'Resend code',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _cooldown > 0 || _sending
                      ? AppColors.textTertiary
                      : AppColors.accentText,
                ),
              ),
            ),
          ),
          Text(
            "Check your spam folder if it isn't in your inbox.",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError(this.message);

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption(fontSize: 12, color: AppColors.danger),
    );
  }
}
