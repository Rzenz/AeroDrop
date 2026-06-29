import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_loading) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _loading = false;
          _sent = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background Radial Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.2),
                  radius: 0.8,
                  colors: [
                    Color(0xFF102847),
                    AppColors.bgDark,
                  ],
                ),
              ),
            ),
          ),

          // Ambient yellow glow in top-left
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.cardDark.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.borderDark,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),

                  const SizedBox(height: 40),

                  if (_sent) ...[
                    // Success View: Centered clean structure with Lottie
                    Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.06),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: ClipOval(
                          child: Lottie.asset(
                            'assets/lottie/email_sent.json',
                            repeat: false,
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .scale(curve: Curves.elasticOut, duration: 700.ms),
                    const SizedBox(height: 32),
                    Text(
                      'Authentication Sent',
                      style: AppTextStyles.display(
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'A secure reset link has been dispatched to\n${_emailController.text}',
                        style: AppTextStyles.body(
                          fontSize: 14.5,
                          color: AppColors.textSecondaryDark,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 40),
                    GradientButton(
                      text: 'Back to Login',
                      onPressed: () => context.go('/login'),
                      icon: Icons.login_rounded,
                    ).animate().fadeIn(delay: 500.ms),
                  ] else ...[
                    // Request Reset View: Centered glass card with pulsing key icon
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2 + (_pulseController.value * 0.25),
                                  ),
                                  blurRadius: 15 + (_pulseController.value * 15),
                                  spreadRadius: 2 + (_pulseController.value * 4),
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    )
                        .animate()
                        .scale(curve: Curves.elasticOut, duration: 600.ms),
                    const SizedBox(height: 28),
                    Text(
                      'Reset Password',
                      style: AppTextStyles.display(
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Verify your university credentials below to receive a secure recovery link.",
                        style: AppTextStyles.body(
                          fontSize: 14.5,
                          color: AppColors.textSecondaryDark,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 36),
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(28),
                      borderGradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.primary, Colors.transparent],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CustomTextField(
                              labelText: 'Email',
                              hintText: 'yourname@email.com',
                              prefixIcon: Icons.email_outlined,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Email is required'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            GradientButton(
                              text: 'Request Link',
                              isLoading: _loading,
                              onPressed: _handleSubmit,
                              icon: Icons.send_rounded,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
