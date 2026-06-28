import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'presentation/controllers/register_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/widgets/custom_app_bar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.user;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (ref.read(authProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard to prevent animation jank during transition
      FocusScope.of(context).unfocus();

      final success = await ref.read(authProvider.notifier).register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            _selectedRole,
          );
      if (success && mounted) {
        // Let the button state settle before navigating
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;

        if (_selectedRole == UserRole.admin) {
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
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Registration'),
      body: Stack(
        children: [
          // Background: Asymmetric diagonal section break
          Positioned.fill(
            child: CustomPaint(
              painter: _DiagonalBackgroundPainter(),
            ),
          ),

          // Ambient blue glow in bottom right
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Title section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.primary],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Account',
                                style: AppTextStyles.display(
                                  fontSize: 32,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Join the AeroDrop autonomous network',
                                style: AppTextStyles.body(
                                  fontSize: 14,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 32),

                    // Registration form card
                    DarkCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(28),
                      borderGradient: LinearGradient(
                        colors: [
                          AppColors.borderDark,
                          AppColors.primary.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            labelText: 'Full Name',
                            hintText: 'Juan dela Cruz',
                            prefixIcon: Icons.person_outline_rounded,
                            controller: _nameController,
                            validator: RegisterController.validateName,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 18),
                          CustomTextField(
                            labelText: 'University Email',
                            hintText: 'yourname@uclm.edu',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: RegisterController.validateEmail,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 18),
                          CustomTextField(
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondaryDark,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                            validator: RegisterController.validatePassword,
                          ),
                          const SizedBox(height: 24),

                          // Role selector
                          Text(
                            'ASSIGN ROLE',
                            style: AppTextStyles.label(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.bgDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.borderDark,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RoleTab(
                                    label: 'User Portal',
                                    selected: _selectedRole == UserRole.user,
                                    onTap: () => setState(() =>
                                        _selectedRole = UserRole.user),
                                  ),
                                ),
                                Expanded(
                                  child: _RoleTab(
                                    label: 'Command Deck',
                                    selected: _selectedRole == UserRole.admin,
                                    onTap: () => setState(() =>
                                        _selectedRole = UserRole.admin),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          GradientButton(
                            text: 'Register Account',
                            isLoading: authState.isLoading,
                            onPressed: _handleRegister,
                            icon: Icons.rocket_launch_rounded,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 150.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 32),

                    // Sign-in redirection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Sign In',
                            style: AppTextStyles.body(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentLight,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 250.ms),
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

class _RoleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.title(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.bgDark : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}

class _DiagonalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill background with navy
    final bgPaint = Paint()..color = AppColors.bgDark;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw top-left diagonal accent area
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.8, 0);
    path.lineTo(0, size.height * 0.22);
    path.close();

    final accentPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0F2B48),
          Color(0xFF0D1B2A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.8, size.height * 0.22));

    canvas.drawPath(path, accentPaint);

    // Draw separating line
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(size.width * 0.8, 0), Offset(0, size.height * 0.22), linePaint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalBackgroundPainter oldDelegate) => false;
}
