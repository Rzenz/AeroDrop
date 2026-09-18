import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/auth_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/providers/auth_provider.dart';

enum VerificationMethod { email, sms }

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  late VerificationMethod _method;
  bool _isLoading = false;
  bool _resending = false;
  int _timerSeconds = 60;
  Timer? _timer;
  bool _initialSent = false;

  final List<TextEditingController> _controllers = List.generate(
    AuthConstants.otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    AuthConstants.otpLength,
    (_) => FocusNode(),
  );

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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
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
    final success =
        await ref.read(authProvider.notifier).sendLoginOtp(viaSms: viaSms);
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
      for (var c in _controllers) {
        c.clear();
      }
    });
    ref.read(authProvider.notifier).setOtpDeliveryMethod(
          newMethod == VerificationMethod.sms ? 'sms' : 'email',
        );
    _resendCode();
  }

  void _verifyCode() async {
    final code = _controllers.map((c) => c.text.trim()).join();
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
    final success = await ref.read(authProvider.notifier).verifyLoginOtp(
          token: code,
          viaSms: viaSms,
        );

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
      final errorMsg = ref.read(authProvider).errorMessage ??
          'Unable to verify the code. Please try again.';
      showNeuSnack(
        context,
        errorMsg,
        tone: NeuToneKind.error,
      );
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userEmail = _maskEmail(user?.email ?? '');
    final userPhone = _maskPhoneNumber(user?.phoneNumber);
    final hasPhone =
        user?.phoneNumber != null && user!.phoneNumber!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium pulsing icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _method == VerificationMethod.email
                          ? Icons.mark_email_read_rounded
                          : Icons.sms_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),

                  const SizedBox(height: 28),

                  Text(
                    'Security Verification',
                    style: AppTextStyles.title(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 10),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _method == VerificationMethod.email
                          ? 'We sent a ${AuthConstants.otpLength}-digit verification code to your email:\n$userEmail'
                          : (!hasPhone
                              ? 'No phone number is registered for this account.'
                              : 'We sent a ${AuthConstants.otpLength}-digit verification code to your registered mobile number:\n$userPhone'),
                      key: ValueKey(_method),
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Option to toggle between Email and SMS if phone is available
                  if (hasPhone)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Email Code'),
                          selected: _method == VerificationMethod.email,
                          onSelected: (selected) {
                            if (selected) {
                              _switchMethod(VerificationMethod.email);
                            }
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundColor: const Color(0xFF101926),
                          labelStyle: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: _method == VerificationMethod.email
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _method == VerificationMethod.email
                                ? AppColors.primaryLight
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Send code to phone instead'),
                          selected: _method == VerificationMethod.sms,
                          onSelected: (selected) {
                            if (selected) _switchMethod(VerificationMethod.sms);
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundColor: const Color(0xFF101926),
                          labelStyle: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: _method == VerificationMethod.sms
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _method == VerificationMethod.sms
                                ? AppColors.primaryLight
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(AuthConstants.otpLength, (index) {
                      return SizedBox(
                        width: 42,
                        height: 52,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: AppTextStyles.heading(
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFF101926),
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length == 1) {
                              if (index < AuthConstants.otpLength - 1) {
                                _focusNodes[index + 1].requestFocus();
                              } else {
                                _focusNodes[index].unfocus();
                              }
                            } else if (value.isEmpty) {
                              if (index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            }
                          },
                        ),
                      );
                    }),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),

                  const SizedBox(height: 36),

                  NeuCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        NeuButton(
                          text: 'Verify & Proceed',
                          isLoading: _isLoading,
                          onPressed: _verifyCode,
                          icon: Icons.verified_user_rounded,
                        ),
                        const SizedBox(height: 20),
                        // Resend code or timer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive the code? ",
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            _timerSeconds > 0
                                ? Text(
                                    'Resend in ${_timerSeconds}s',
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _resending ? null : _resendCode,
                                    child: Text(
                                      _resending ? 'Sending...' : 'Resend',
                                      style: AppTextStyles.body(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // Back to Login / Sign out option
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    icon: Icon(Icons.logout_rounded,
                        size: 16, color: AppColors.textTertiary),
                    label: Text(
                      'Sign out and use another account',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
