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

enum VerificationMethod { email, sms }

class WebVerificationPage extends ConsumerStatefulWidget {
  const WebVerificationPage({super.key});

  @override
  ConsumerState<WebVerificationPage> createState() =>
      _WebVerificationPageState();
}

class _WebVerificationPageState extends ConsumerState<WebVerificationPage> {
  late VerificationMethod _method;
  bool _isLoading = false;
  bool _resending = false;
  int _timerSeconds = 60;
  Timer? _timer;
  bool _initialSent = false;

  /// The whole code, in one field — see [AuthCodeInput].
  final _codeController = TextEditingController();

  /// Set when a code is rejected; the cells take the danger outline until
  /// the next keystroke. The tick shakes the row once per rejection.
  bool _codeRejected = false;
  int _rejections = 0;

  @override
  void initState() {
    super.initState();
    // Email is always default on load; phone is never auto-selected.
    _method = VerificationMethod.email;

    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialOtp();
    });
  }

  Future<void> _sendInitialOtp() async {
    if (_initialSent) return;
    _initialSent = true;
    final viaSms = _method == VerificationMethod.sms;
    final success = await ref
        .read(authProvider.notifier)
        .sendLoginOtp(viaSms: viaSms);
    if (!mounted) return;
    if (success) {
      final destination = viaSms ? 'mobile number' : 'email address';
      showNeuSnack(
        context,
        'Verification code sent to your $destination!',
        tone: NeuToneKind.info,
      );
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Failed to send code.';
      showNeuSnack(context, err, tone: NeuToneKind.error);
    }
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

  void _resendCode() async {
    if (_resending || _timerSeconds > 0) return;
    setState(() => _resending = true);
    final viaSms = _method == VerificationMethod.sms;
    final success = await ref
        .read(authProvider.notifier)
        .sendLoginOtp(viaSms: viaSms);
    if (mounted) {
      setState(() => _resending = false);
      if (success) {
        _startTimer();
        final destination = viaSms ? 'mobile number' : 'email address';
        showNeuSnack(
          context,
          'Verification code resent to your $destination!',
          tone: NeuToneKind.success,
        );
      } else {
        final err =
            ref.read(authProvider).errorMessage ?? 'Failed to resend code.';
        showNeuSnack(context, err, tone: NeuToneKind.error);
      }
    }
  }

  void _switchMethod(VerificationMethod newMethod) async {
    if (_method == newMethod || _isLoading || _resending) return;
    setState(() {
      _method = newMethod;
      _codeController.clear();
      _codeRejected = false;
    });
    ref
        .read(authProvider.notifier)
        .setOtpDeliveryMethod(
          newMethod == VerificationMethod.sms ? 'sms' : 'email',
        );
    _resendCode();
  }

  void _verifyCode() async {
    if (_isLoading) return;
    final code = _codeController.text.trim();
    if (code.length < AuthConstants.otpLength) {
      showNeuSnack(
        context,
        'Please enter the complete ${AuthConstants.otpLength}-digit code.',
        tone: NeuToneKind.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final viaSms = _method == VerificationMethod.sms;
    final success = await ref
        .read(authProvider.notifier)
        .verifyLoginOtp(token: code, viaSms: viaSms);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final user = ref.read(authProvider).user;
      if (user?.isAdmin == true) {
        context.go('/admin');
      } else if (user?.vendorStatus == 'pending') {
        context.go('/account-pending');
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
      final errorMsg =
          ref.read(authProvider).errorMessage ??
          'Unable to verify the code. Please try again.';
      showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
    }
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
      return 'No phone number registered';
    }
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.length >= 7) {
      final end = clean.substring(clean.length - 4);
      final start = clean.substring(0, clean.length - 4);
      if (start.length > 3) {
        final countryAndPrefix = start.substring(0, start.length - 2);
        return '$countryAndPrefix•• ••• $end';
      } else {
        return '$start•• ••• $end';
      }
    }
    return phone;
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final hasPhone =
        user?.phoneNumber != null && user!.phoneNumber!.trim().isNotEmpty;
    final viaEmail = _method == VerificationMethod.email;
    final destination = viaEmail
        ? _maskEmail(user?.email ?? '')
        : _maskPhoneNumber(user?.phoneNumber);
    final complete = _codeController.text.length == AuthConstants.otpLength;

    var i = 0;
    Widget row(Widget child) => child.authReveal(context, i++);

    return AuthCenterShell(
      // Leaving this page means leaving the half-finished sign-in, so Back
      // signs out — otherwise the router would send it straight back here.
      onBack: _signOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            AuthHeading(
              inCard: true,
              title: viaEmail ? 'Check your email' : 'Check your phone',
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
                  children: viaEmail || hasPhone
                      ? [
                          TextSpan(
                            text:
                                'Enter the ${AuthConstants.otpLength}-digit '
                                'code we sent to ',
                          ),
                          TextSpan(
                            text: destination,
                            style: const TextStyle(
                              color: WebInk.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ]
                      : const [
                          TextSpan(
                            text:
                                'No phone number is registered for this '
                                'account.',
                          ),
                        ],
                ),
                key: ValueKey(_method),
                textAlign: TextAlign.center,
                style: WebType.body().copyWith(fontSize: 15.5, height: 1.55),
              ),
            ),
          ),
          if (hasPhone) ...[
            SizedBox(height: context.authGap(22)),
            row(
              AuthSegmented(
                options: const ['Email', 'Text message'],
                icons: const [Icons.mail_outline_rounded, Icons.sms_outlined],
                selectedIndex: viaEmail ? 0 : 1,
                onSelected: (i) => _switchMethod(
                  i == 0 ? VerificationMethod.email : VerificationMethod.sms,
                ),
              ),
            ),
          ],
          SizedBox(height: context.authGap(28)),
          row(
            AuthCodeInput(
              controller: _codeController,
              length: AuthConstants.otpLength,
              hasError: _codeRejected,
              errorTick: _rejections,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_codeRejected) setState(() => _codeRejected = false);
                setState(() {});
              },
              // The last digit submits: there is nothing else to fill in.
              onCompleted: (_) => _verifyCode(),
            ),
          ),
          SizedBox(height: context.authGap(24)),
          row(
            AuthButton(
              text: 'Verify and continue',
              isLoading: _isLoading,
              onPressed: complete ? _verifyCode : null,
            ),
          ),
          SizedBox(height: context.authGap(18)),
          row(
            AuthResendLine(
              secondsLeft: _timerSeconds,
              sending: _resending,
              onResend: _resendCode,
            ),
          ),
          SizedBox(height: context.authGap(18)),
          row(const WebRule()),
          SizedBox(height: context.authGap(6)),
          row(
            Center(
              child: AuthTextLink(
                label: 'Sign out and use another account',
                icon: Icons.logout_rounded,
                color: WebInk.textSoft,
                onTap: _signOut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
