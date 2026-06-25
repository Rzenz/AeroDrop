import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'john.doe@uclm.edu');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
      if (success && mounted) {
        final user = ref.read(authProvider).user;
        if (user?.role == UserRole.admin) {
          context.go('/admin');
        } else {
          context.go('/user');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: Stack(
          children: [
            // Ambient glow orbs
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.secondary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Logo + title
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: const Icon(
                            Icons.flight_takeoff_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ).animate().scale(
                              duration: 500.ms,
                              curve: Curves.elasticOut,
                            ),

                        const SizedBox(height: 20),

                        Text(
                          'Welcome Back',
                          style: AppTextStyles.title(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to your AeroDrop portal',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.textSecondaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 250.ms),

                        const SizedBox(height: 36),

                        // Glass form card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              const SizedBox(height: 16),
                              CustomTextField(
                                labelText: 'Password',
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_outline_rounded,
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondaryDark,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      context.push('/forgot-password'),
                                  child: Text(
                                    'Forgot Password?',
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              CustomButton(
                                text: 'Sign In',
                                isLoading: authState.isLoading,
                                onPressed: _handleLogin,
                                icon: Icons.login_rounded,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.08),

                        const SizedBox(height: 24),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: AppTextStyles.body(
                                  fontSize: 14,
                                  color: AppColors.textSecondaryDark),
                            ),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              child: Text(
                                'Register',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 450.ms),

                        const SizedBox(height: 16),

                        // Demo chips
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _DemoChip(
                              label: '👤 User Demo',
                              onTap: () {
                                _emailController.text = 'john.doe@uclm.edu';
                                _passwordController.text = 'password123';
                              },
                            ),
                            _DemoChip(
                              label: '🛡️ Admin Demo',
                              onTap: () {
                                _emailController.text =
                                    'admin.portal@uclm.edu';
                                _passwordController.text = 'admin123';
                              },
                            ),
                          ],
                        ).animate().fadeIn(delay: 550.ms),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DemoChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDark),
          borderRadius: BorderRadius.circular(20),
          color: AppColors.cardDark.withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
