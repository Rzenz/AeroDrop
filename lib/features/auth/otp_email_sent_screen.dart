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

enum RegistrationOtpMethod { email, sms }

class OtpEmailSentScreen extends ConsumerStatefulWidget {
  final String email;
  final String? phone;
  final String? role;
  final String type; // 'verification' or 'reset'

  const OtpEmailSentScreen({
    super.key,
    required this.email,
    this.phone,
    this.role,
    this.type = 'verification',
  });

  @override
  ConsumerState<OtpEmailSentScreen> createState() => _OtpEmailSentScreenState();
}

class _OtpEmailSentScreenState extends ConsumerState<OtpEmailSentScreen> {
  late RegistrationOtpMethod _method;
  int _timerSeconds = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

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
    _method = RegistrationOtpMethod.email;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
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
      final error = ref.read(authProvider).errorMessage ??
          'Failed to resend verification code. Please try again.';
      final isRateLimit = error.toLowerCase().contains('too many attempts') ||
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
  }

  void _switchMethod(RegistrationOtpMethod newMethod) async {
    if (_method == newMethod || _isVerifying || _isResending) return;
    setState(() {
      _method = newMethod;
      for (final c in _controllers) {
        c.clear();
      }
    });
    _resendCode();
  }

  Future<void> _handleVerify() async {
    final code = _controllers.map((c) => c.text.trim()).join();
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

    final targetEmail = widget.email.isNotEmpty
        ? widget.email
        : (ref.read(authProvider).pendingEmail ?? '');
    final targetPhone = widget.phone ?? ref.read(authProvider).pendingPhone;
    final viaSms = _method == RegistrationOtpMethod.sms;
    bool success = false;
    if (widget.type == 'reset') {
      success = await ref.read(authProvider.notifier).verifyPasswordResetOtp(
            token: code,
            email: targetEmail,
          );
    } else {
      success = await ref.read(authProvider.notifier).verifyRegistrationOtp(
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
        showNeuSnack(
          context,
          authError,
          tone: NeuToneKind.info,
        );
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
      final error = ref.read(authProvider).errorMessage ??
          'Verification failed. Please check the code and try again.';
      showNeuSnack(context, error, tone: NeuToneKind.error);
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

    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AeroDrop Branded Shield / Mail Badge
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isResetFlow
                              ? Icons.lock_reset_rounded
                              : (_method == RegistrationOtpMethod.sms
                                  ? Icons.sms_rounded
                                  : Icons.mark_email_read_rounded),
                          color: AppColors.accent,
                          size: 44,
                        ),
                      ),
                    ).animate().scale(
                          curve: Curves.elasticOut,
                          duration: 600.ms,
                        ),
                    const SizedBox(height: 24),

                    Text(
                      isResetFlow ? 'Password Reset Code' : 'Verify Your Account',
                      style: AppTextStyles.display(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 10),

                    Text(
                      isResetFlow
                          ? 'We sent a password recovery code to:'
                          : (_method == RegistrationOtpMethod.sms
                              ? 'We sent a ${AuthConstants.otpLength}-digit registration code via SMS to:'
                              : 'We sent a ${AuthConstants.otpLength}-digit registration code to your email:'),
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 180.ms),
                    const SizedBox(height: 6),

                    Text(
                      _method == RegistrationOtpMethod.sms
                          ? _maskPhoneNumber(targetPhone)
                          : _maskEmail(targetEmail),
                      style: AppTextStyles.subHead(
                        fontSize: 16,
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 240.ms),

                    const SizedBox(height: 20),

                    // Method toggle if phone is provided and in verification flow
                    if (!isResetFlow && hasPhone) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Email OTP'),
                            selected: _method == RegistrationOtpMethod.email,
                            onSelected: (selected) {
                              if (selected) {
                                _switchMethod(RegistrationOtpMethod.email);
                              }
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundColor: const Color(0xFF101926),
                            labelStyle: AppTextStyles.body(
                              fontSize: 12,
                              fontWeight: _method == RegistrationOtpMethod.email
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _method == RegistrationOtpMethod.email
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('SMS OTP'),
                            selected: _method == RegistrationOtpMethod.sms,
                            onSelected: (selected) {
                              if (selected) {
                                _switchMethod(RegistrationOtpMethod.sms);
                              }
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundColor: const Color(0xFF101926),
                            labelStyle: AppTextStyles.body(
                              fontSize: 12,
                              fontWeight: _method == RegistrationOtpMethod.sms
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _method == RegistrationOtpMethod.sms
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 260.ms),
                      const SizedBox(height: 20),
                    ],

                    NeuCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter ${AuthConstants.otpLength}-Digit Code',
                            style: AppTextStyles.subHead(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),

                          // OTP Digit Boxes
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
                          ),
                          const SizedBox(height: 24),

                          NeuButton(
                            text: isResetFlow
                                ? 'Verify Reset Code'
                                : 'Verify & Complete Registration',
                            isLoading: _isVerifying,
                            onPressed: _handleVerify,
                            icon: Icons.verified_user_rounded,
                          ),
                          const SizedBox(height: 18),

                          // Resend Code timer / link
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
                                      onTap:
                                          _isResending ? null : _resendCode,
                                      child: Text(
                                        _isResending
                                            ? 'Sending...'
                                            : 'Resend Code',
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
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),

                    const SizedBox(height: 24),

                    // Change Email / Back to Register & Back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.pop();
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Change Details'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/login');
                          },
                          child: Text(
                            'Back to Login',
                            style: AppTextStyles.subHead(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 380.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
