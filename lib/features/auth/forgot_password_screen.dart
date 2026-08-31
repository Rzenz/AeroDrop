import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_back_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
        });
        context.push(
          '/email-sent',
          extra: {'email': _emailController.text, 'type': 'reset'},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(
        children: [
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
                    child: NeuBackButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),

                  const SizedBox(height: 40),

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
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 38,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
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
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 36),
                  NeuCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(28),
                    accent: AppColors.accent,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          NeuTextField(
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
                          NeuButton(
                            text: 'Request Link',
                            isLoading: _loading,
                            onPressed: _handleSubmit,
                            icon: Icons.send_rounded,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
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
