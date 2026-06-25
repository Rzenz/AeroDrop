import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _loading = false; _sent = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.1),

                const Spacer(),

                if (_sent) ...[
                  // Success state
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Lottie.asset(
                      'assets/lottie/email_sent.json',
                      repeat: false,
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Check Your Email',
                    style: AppTextStyles.title(
                        fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a password reset link to\n${_emailController.text}',
                    style: AppTextStyles.body(
                        fontSize: 14, color: AppColors.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: 36),
                  CustomButton(
                    text: 'Back to Login',
                    onPressed: () => context.go('/login'),
                    icon: Icons.login_rounded,
                  ).animate().fadeIn(delay: 500.ms),
                ] else ...[
                  // Form state
                  ShaderMask(
                    shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                    child: const Icon(Icons.lock_reset_rounded,
                        size: 56, color: Colors.white),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Reset Password',
                    style: AppTextStyles.title(
                        fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 10),
                  Text(
                    "Enter your university email and we'll send you a reset link.",
                    style: AppTextStyles.body(
                        fontSize: 14, color: AppColors.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            labelText: 'University Email',
                            hintText: 'yourname@uclm.edu',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            text: 'Send Reset Link',
                            isLoading: _loading,
                            onPressed: _handleSubmit,
                            icon: Icons.send_rounded,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
                ],

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
