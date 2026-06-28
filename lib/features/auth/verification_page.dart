import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';

enum VerificationMethod { email, sms }

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  VerificationMethod _method = VerificationMethod.email;
  bool _isLoading = false;
  bool _resending = false;
  int _timerSeconds = 59;
  Timer? _timer;

  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
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
      final destination = _method == VerificationMethod.email ? 'email' : 'phone number';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code resent to your $destination!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _toggleMethod() {
    setState(() {
      _method = _method == VerificationMethod.email ? VerificationMethod.sms : VerificationMethod.email;
      // Clear inputs
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    });
    _resendCode();
  }

  void _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the complete 6-digit code.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    // Simulate verification check
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      // Navigate to dashboard based on role
      final user = ref.read(authProvider).user;
      if (user?.role == UserRole.admin) {
        context.go('/admin');
      } else {
        context.go('/user');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? 'm***@uclm.edu.ph';
    final userPhone = '+63 9•• ••• ••98';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
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
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  
                  const SizedBox(height: 12),
                  
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _method == VerificationMethod.email
                          ? 'We sent a 6-digit verification code to your university email:\n$userEmail'
                          : 'We sent a 6-digit verification code to your registered mobile number:\n$userPhone',
                      key: ValueKey(_method),
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondaryDark,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                  
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        CustomButton(
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
                                color: AppColors.textSecondaryDark,
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
                        const Divider(height: 32, color: Colors.white10),
                        // Try another way option
                        TextButton.icon(
                          onPressed: _toggleMethod,
                          icon: Icon(
                            _method == VerificationMethod.email
                                ? Icons.phone_android_rounded
                                : Icons.email_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          label: Text(
                            _method == VerificationMethod.email
                                ? 'Try another way: Verify via SMS'
                                : 'Try another way: Verify via Email',
                            style: AppTextStyles.body(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
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
