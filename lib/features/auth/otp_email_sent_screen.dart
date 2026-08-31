import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/providers/auth_provider.dart';

class OtpEmailSentScreen extends ConsumerStatefulWidget {
  final String email;
  final String type; // 'verification' or 'reset'

  const OtpEmailSentScreen({
    super.key,
    required this.email,
    required this.type,
  });

  @override
  ConsumerState<OtpEmailSentScreen> createState() => _OtpEmailSentScreenState();
}

class _OtpEmailSentScreenState extends ConsumerState<OtpEmailSentScreen> {
  int _timerSeconds = 59;
  Timer? _timer;
  bool _resending = false;
  bool _showSmsInput = false;
  late TextEditingController _smsController;
  bool _verifyingSms = false;

  @override
  void initState() {
    super.initState();
    _smsController = TextEditingController(text: '123456');
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsController.dispose();
    super.dispose();
  }

  void _verifySmsCode() async {
    final code = _smsController.text.trim();
    if (code.isEmpty) {
      showNeuSnack(
        context,
        'Please enter a verification code.',
        tone: NeuToneKind.error,
      );
      return;
    }

    setState(() => _verifyingSms = true);
    HapticFeedback.mediumImpact();

    // Simulate verification check
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() => _verifyingSms = false);
      final user = ref.read(authProvider).user;
      if (user?.isAdmin == true) {
        context.go('/admin');
      } else if (user?.isVendor == true) {
        context.go('/vendor');
      } else {
        context.go('/user');
      }
    }
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

  void _resendEmail() async {
    if (_resending || _timerSeconds > 0) return;
    setState(() => _resending = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _resending = false);
      _startTimer();
      showNeuSnack(
        context,
        widget.type == 'reset'
            ? 'Password reset link resent!'
            : 'Verification email resent!',
        tone: NeuToneKind.success,
      );
    }
  }

  void _openEmailApp() {
    HapticFeedback.lightImpact();
    showNeuSnack(
      context,
      'Directing to your email client...',
      tone: NeuToneKind.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'reset'
        ? 'Reset Link Dispatched'
        : 'Verification Dispatched';
    final desc = widget.type == 'reset'
        ? 'We have sent a secure recovery link to:'
        : 'We have sent an authentication link to:';

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
                    // Icon
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: AppColors.accent,
                          size: 44,
                        ),
                      ),
                    ).animate().scale(
                      curve: Curves.elasticOut,
                      duration: 600.ms,
                    ),
                    const SizedBox(height: 28),

                    Text(
                      title,
                      style: AppTextStyles.display(
                        fontSize: 26,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 12),

                    Text(
                      desc,
                      style: AppTextStyles.body(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 180.ms),
                    const SizedBox(height: 8),

                    Text(
                      widget.email,
                      style: AppTextStyles.subHead(
                        fontSize: 16,
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 240.ms),
                    const SizedBox(height: 36),

                    NeuCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: !_showSmsInput
                            ? Column(
                                key: const ValueKey('email_form'),
                                children: [
                                  NeuButton(
                                    text: 'Open Email App',
                                    onPressed: _openEmailApp,
                                    icon: Icons.mail_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: (_resending || _timerSeconds > 0)
                                        ? null
                                        : _resendEmail,
                                    child: Text(
                                      _timerSeconds > 0
                                          ? 'Resend in ${_timerSeconds}s'
                                          : 'Resend Email',
                                      style: AppTextStyles.subHead(
                                        fontSize: 13,
                                        color: _timerSeconds > 0
                                            ? AppColors.textSecondary
                                            : AppColors.accentLight,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    height: 32,
                                    color: AppColors.surfaceSunken,
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _showSmsInput = true),
                                    icon: const Icon(
                                      Icons.phone_android_rounded,
                                      size: 16,
                                      color: AppColors.accent,
                                    ),
                                    label: Text(
                                      'Verify via SMS Code instead',
                                      style: AppTextStyles.subHead(
                                        fontSize: 13,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('sms_form'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Enter SMS Code',
                                    style: AppTextStyles.subHead(
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Type the numeric code sent to your phone',
                                    style: AppTextStyles.body(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  NeuTextField(
                                    labelText: 'SMS Code',
                                    hintText: 'e.g. 123456',
                                    prefixIcon: Icons.pin_rounded,
                                    controller: _smsController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  NeuButton(
                                    text: 'Verify & Proceed',
                                    isLoading: _verifyingSms,
                                    onPressed: _verifySmsCode,
                                    icon: Icons.verified_user_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _showSmsInput = false),
                                    child: Text(
                                      'Back to Email verification',
                                      style: AppTextStyles.subHead(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                    const SizedBox(height: 28),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/login');
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to Login'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
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
