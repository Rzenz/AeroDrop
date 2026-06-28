import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  bool _resending = false;

  void _resendEmail() async {
    setState(() => _resending = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _resending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email resent successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _refreshStatus() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/user');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 48),
                ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                const SizedBox(height: 32),
                Text(
                  'Verify Your Email',
                  style: AppTextStyles.title(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 12),
                Text(
                  'We have sent a verification link to your university email. Please click the link to verify your account.',
                  style: AppTextStyles.body(fontSize: 14, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 36),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      CustomButton(
                        text: 'I Have Verified',
                        isLoading: _isLoading,
                        onPressed: _refreshStatus,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _resending ? null : _resendEmail,
                        child: Text(
                          _resending ? 'Sending...' : 'Resend Verification Email',
                          style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
