import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/providers/auth_provider.dart';

enum VerificationMethod { email, sms }

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  final VerificationMethod _method = VerificationMethod.sms;
  bool _isLoading = false;
  bool _resending = false;
  int _timerSeconds = 59;
  Timer? _timer;

  final List<TextEditingController> _controllers = [
    TextEditingController(text: '1'),
    TextEditingController(text: '2'),
    TextEditingController(text: '3'),
    TextEditingController(text: '4'),
    TextEditingController(text: '5'),
    TextEditingController(text: '6'),
  ];
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _startTimer();
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
      _timerSeconds = 59;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resendCode() async {
    setState(() => _resending = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _resending = false);
      _startTimer();
      final destination = _method == VerificationMethod.email
          ? 'email'
          : 'phone number';
      showNeuSnack(
        context,
        'Verification code resent to your $destination!',
        tone: NeuToneKind.success,
      );
    }
  }

  void _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      showNeuSnack(
        context,
        'Please enter the complete 6-digit code.',
        tone: NeuToneKind.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Simulate verification check
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Complete verification session
      ref.read(authProvider.notifier).completeVerification();

      // GoRouter redirect automatically routes user to their correct dashboard
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showNeuSnack(
          context,
          'Unable to verify the code. Please try again.',
          tone: NeuToneKind.error,
        );
      }
    }
  }

  String _maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'No phone number is registered for this account.';
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
    final userEmail = user?.email ?? 'm***@gmail.com';
    final userPhone = _maskPhoneNumber(user?.phoneNumber);

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
                          : Icons.sms_failed_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),

                  const SizedBox(height: 32),

                  Text(
                    'Security Verification',
                    style: AppTextStyles.title(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 12),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _method == VerificationMethod.email
                          ? 'We sent a 6-digit verification code to your email:\n$userEmail'
                          : (user?.phoneNumber == null ||
                                user!.phoneNumber!.trim().isEmpty)
                          ? 'No phone number is registered for this account.'
                          : 'We sent a 6-digit verification code to your registered mobile number:\n$userPhone',
                      key: ValueKey(_method),
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 36),

                  // OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
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
                              if (index < 5) {
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
