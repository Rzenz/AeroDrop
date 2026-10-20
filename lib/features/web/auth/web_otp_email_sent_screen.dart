import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/auth_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/neu_feedback.dart';
import '../web_tokens.dart';
import '../widgets/web_motion.dart';
import '../../auth/widgets/auth_kit.dart';

enum RegistrationOtpMethod { email, sms }

class WebOtpEmailSentScreen extends ConsumerStatefulWidget {
  final String email;
  final String? phone;
  final String? role;
  final String type; // 'verification' or 'reset'
  final bool isGoogleOnly;

  const WebOtpEmailSentScreen({
    super.key,
    required this.email,
    this.phone,
    this.role,
    this.type = 'verification',
    this.isGoogleOnly = false,
  });

  @override
  ConsumerState<WebOtpEmailSentScreen> createState() =>
      _WebOtpEmailSentScreenState();
}

class _WebOtpEmailSentScreenState extends ConsumerState<WebOtpEmailSentScreen> {
  late RegistrationOtpMethod _method;
  int _timerSeconds = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

  /// The whole code, in one field — see [AuthCodeInput].
  final _codeController = TextEditingController();

  /// Set when a code is rejected; cleared on the next keystroke.
  bool _codeRejected = false;
  int _rejections = 0;

  @override
  void initState() {
    super.initState();
    _method = RegistrationOtpMethod.email;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return 'your email';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}•••@$domain';
    }
    final maskedName = '${name.substring(0, 2)}${'•' * (name.length - 2)}';
    return '$maskedName@$domain';
  }

  String _maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'your registered mobile number';
    }
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.length >= 7) {
      final end = clean.substring(clean.length - 4);
      final start = clean.substring(0, clean.length - 4);
      if (start.length > 3) {
        final countryAndPrefix = start.substring(0, start.length - 2);
        return '$countryAndPrefix•• ••• $end';
      }
      return '$start•• ••• $end';
    }
    return phone;
  }

  Future<void> _resendCode() async {
    if (_isResending || _timerSeconds > 0) return;

    setState(() => _isResending = true);
    try {
      final viaSms = _method == RegistrationOtpMethod.sms;

      final targetEmail = widget.email.isNotEmpty
          ? widget.email
          : (ref.read(authProvider).pendingEmail ?? '');
      final targetPhone = widget.phone ?? ref.read(authProvider).pendingPhone;

      bool success = false;
      if (widget.type == 'reset') {
        success = await ref
            .read(authProvider.notifier)
            .sendPasswordReset(targetEmail);
      } else {
        success = await ref
            .read(authProvider.notifier)
            .resendRegistrationOtp(
              email: targetEmail,
              phone: targetPhone,
              viaSms: viaSms,
            );
      }

      if (!mounted) return;
      setState(() => _isResending = false);

      if (success) {
        _startTimer();
        final destination = viaSms ? 'phone number' : 'email';
        showNeuSnack(
          context,
          'Verification code resent to your $destination!',
          tone: NeuToneKind.success,
        );
      } else {
        final error =
            ref.read(authProvider).errorMessage ??
            'Failed to resend verification code. Please try again.';
        final isRateLimit =
            error.toLowerCase().contains('too many attempts') ||
            error.toLowerCase().contains('rate limit') ||
            error.toLowerCase().contains('wait') ||
            error.toLowerCase().contains('seconds');
        if (isRateLimit) {
          _startTimer();
          showNeuSnack(
            context,
            'Please wait for the timer before requesting a new code.',
            tone: NeuToneKind.info,
          );
        } else {
          showNeuSnack(context, error, tone: NeuToneKind.error);
        }
      }
    } catch (e) {
      debugPrint('Error resending verification code: $e');
      if (mounted) {
        setState(() => _isResending = false);
        showNeuSnack(
          context,
          formatAuthErrorMessage(e),
          tone: NeuToneKind.error,
        );
      }
    }
  }

  void _switchMethod(RegistrationOtpMethod newMethod) async {
    if (_method == newMethod || _isVerifying || _isResending) return;
    setState(() {
      _method = newMethod;
      _codeController.clear();
      _codeRejected = false;
    });
    _resendCode();
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _codeController.text.trim();
    if (code.length < AuthConstants.otpLength) {
      showNeuSnack(
        context,
        'Please enter the complete ${AuthConstants.otpLength}-digit code.',
        tone: NeuToneKind.error,
      );
      return;
    }

    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();

    try {
      final targetEmail = widget.email.isNotEmpty
          ? widget.email
          : (ref.read(authProvider).pendingEmail ?? '');
      final targetPhone = widget.phone ?? ref.read(authProvider).pendingPhone;
      final viaSms = _method == RegistrationOtpMethod.sms;
      bool success = false;
      if (widget.type == 'reset') {
        success = await ref
            .read(authProvider.notifier)
            .verifyPasswordResetOtp(token: code, email: targetEmail);
      } else {
        success = await ref
            .read(authProvider.notifier)
            .verifyRegistrationOtp(
              token: code,
              email: targetEmail,
              phone: targetPhone,
              viaSms: viaSms,
            );
      }

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (success) {
        if (widget.type == 'reset') {
          showNeuSnack(
            context,
            'Recovery code verified. Please set your new password.',
            tone: NeuToneKind.success,
          );
          context.go('/user/profile/change-password');
          return;
        }

        final authError = ref.read(authProvider).errorMessage;
        if (authError != null && authError.isNotEmpty) {
          showNeuSnack(context, authError, tone: NeuToneKind.info);
        } else {
          showNeuSnack(
            context,
            'Account verified successfully!',
            tone: NeuToneKind.success,
          );
        }

        final user = ref.read(authProvider).user;
        final requestedRole = widget.role ?? ref.read(authProvider).pendingRole;
        final isPendingVendor =
            requestedRole == 'vendor' || user?.vendorStatus == 'pending';

        if (isPendingVendor) {
          context.go('/account-pending');
        } else if (user?.isAdmin == true) {
          context.go('/admin');
        } else if (user?.isVendor == true) {
          context.go('/vendor');
        } else {
          context.go('/user');
        }
      } else {
        setState(() {
          _codeRejected = true;
          _rejections++;
        });
        final error =
            ref.read(authProvider).errorMessage ??
            'Verification failed. Please check the code and try again.';
        showNeuSnack(context, error, tone: NeuToneKind.error);
      }
    } catch (e) {
      debugPrint('Error verifying code: $e');
      if (mounted) {
        setState(() => _isVerifying = false);
        showNeuSnack(
          context,
          formatAuthErrorMessage(e),
          tone: NeuToneKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResetFlow = widget.type == 'reset';
    final targetEmail = widget.email.isNotEmpty
        ? widget.email
        : (ref.watch(authProvider).pendingEmail ?? '');
    final targetPhone = widget.phone ?? ref.watch(authProvider).pendingPhone;
    final hasPhone = targetPhone != null && targetPhone.trim().isNotEmpty;
    final viaSms = _method == RegistrationOtpMethod.sms;
    final destination = viaSms
        ? _maskPhoneNumber(targetPhone)
        : _maskEmail(targetEmail);
    final complete = _codeController.text.length == AuthConstants.otpLength;

    var i = 0;
    Widget row(Widget child) => child.authReveal(context, i++);

    return AuthCenterShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            AuthHeading(
              inCard: true,
              title: isResetFlow
                  ? 'Reset your password'
                  : (viaSms ? 'Check your phone' : 'Check your email'),
            ),
          ),
          SizedBox(height: context.authGap(10)),
          row(
            AnimatedSwitcher(
              duration: WebMotion.hover,
              // Full width and centred, under the centred heading — the
              // default layout centres the child at its own width instead.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: isResetFlow
                          ? 'Enter the recovery code we sent to '
                          : 'Enter the ${AuthConstants.otpLength}-digit code '
                                'we sent to ',
                    ),
                    TextSpan(
                      text: destination,
                      style: const TextStyle(
                        color: WebInk.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: isResetFlow
                          ? '.'
                          : ' to finish creating your account.',
                    ),
                  ],
                ),
                key: ValueKey(_method),
                textAlign: TextAlign.center,
                style: WebType.body().copyWith(fontSize: 15.5, height: 1.55),
              ),
            ),
          ),
          if (!isResetFlow && hasPhone) ...[
            SizedBox(height: context.authGap(22)),
            row(
              AuthSegmented(
                options: const ['Email', 'Text message'],
                icons: const [Icons.mail_outline_rounded, Icons.sms_outlined],
                selectedIndex: viaSms ? 1 : 0,
                onSelected: (i) => _switchMethod(
                  i == 0
                      ? RegistrationOtpMethod.email
                      : RegistrationOtpMethod.sms,
                ),
              ),
            ),
          ],
          if (isResetFlow && widget.isGoogleOnly) ...[
            SizedBox(height: context.authGap(20)),
            row(const _GoogleAccountNote()),
          ],
          SizedBox(height: context.authGap(28)),
          row(
            AuthCodeInput(
              controller: _codeController,
              length: AuthConstants.otpLength,
              hasError: _codeRejected,
              errorTick: _rejections,
              enabled: !_isVerifying,
              onChanged: (_) {
                if (_codeRejected) setState(() => _codeRejected = false);
                setState(() {});
              },
              onCompleted: (_) => _handleVerify(),
            ),
          ),
          SizedBox(height: context.authGap(24)),
          row(
            AuthButton(
              text: isResetFlow ? 'Verify recovery code' : 'Verify and finish',
              isLoading: _isVerifying,
              onPressed: complete ? _handleVerify : null,
            ),
          ),
          SizedBox(height: context.authGap(18)),
          row(
            AuthResendLine(
              secondsLeft: _timerSeconds,
              sending: _isResending,
              onResend: _resendCode,
            ),
          ),
          SizedBox(height: context.authGap(18)),
          row(const WebRule()),
          SizedBox(height: context.authGap(6)),
          row(
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              children: [
                AuthTextLink(
                  label: isResetFlow
                      ? 'Use a different email'
                      : 'Change details',
                  icon: Icons.edit_outlined,
                  color: WebInk.textSoft,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(
                          isResetFlow ? '/forgot-password' : '/register',
                        ),
                ),
                AuthTextLink(
                  label: 'Back to sign in',
                  color: WebInk.textSoft,
                  onTap: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// For a password reset on an account that was created with Google: it can
/// keep using Google, or set a password with this code.
class _GoogleAccountNote extends StatelessWidget {
  const _GoogleAccountNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthInk.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebInk.rule),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: WebInk.accent,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This account was created with Google. You can keep signing in '
              'with Google, or use this code to set a password for email '
              'sign-in.',
              style: WebType.body(
                color: WebInk.textSoft,
              ).copyWith(fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
