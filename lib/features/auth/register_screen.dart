import 'dart:math' as math;
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
import 'login_screen.dart'; // Import to reuse DroneSvgPainter

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.user;
  bool _obscurePassword = true;
  late AnimationController _bgRotateController;

  @override
  void initState() {
    super.initState();
    _bgRotateController = AnimationController(
      duration: const Duration(seconds: 45),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bgRotateController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (ref.read(authProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard to prevent animation jank during transition
      FocusScope.of(context).unfocus();

      final success = await ref
          .read(authProvider.notifier)
          .register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            _selectedRole,
          );
      if (success && mounted) {
        // Let the button state settle before navigating
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;

        context.go('/verification');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background: Editorial rich gradient (exactly matching Login)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2B48),
                    AppColors.bgDark,
                    Color(0xFF070D14),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Ambient blue-yellow rotating radar (exactly matching Login)
          Positioned(
            top: -150,
            right: -150,
            child: AnimatedBuilder(
              animation: _bgRotateController,
              builder: (context, child) => Transform.rotate(
                angle: _bgRotateController.value * 2 * math.pi,
                child: child,
              ),
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Ambient yellow glow bottom-left (exactly matching Login)
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main scrollable content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),

                            // Header Section (exactly matching Login)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AeroDrop',
                                      style: AppTextStyles.display(
                                        fontSize: 42,
                                        letterSpacing: -1.5,
                                      ),
                                    ).animate().fadeIn().slideX(begin: -0.1),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UCLM DRONE DELIVERY SYSTEM',
                                      style: AppTextStyles.subHead(
                                        fontSize: 14,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ).animate().fadeIn(delay: 100.ms),
                                  ],
                                ),
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: AnimatedBuilder(
                                      animation: _bgRotateController,
                                      builder: (context, _) {
                                        return SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CustomPaint(
                                            size: const Size(32, 32),
                                            painter: DroneSvgPainter(
                                              animationValue:
                                                  _bgRotateController.value,
                                              lineColor: AppColors.bgDark,
                                              accentColor: const Color(
                                                0xFF4F46E5,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 150.ms)
                                .scale(curve: Curves.elasticOut, duration: 600.ms),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Registration form card (GlassCard to match Login)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              borderRadius: BorderRadius.circular(28),
                              borderGradient: const LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.primary,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.4, 1.0],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: AppTextStyles.title(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start using the UCLM Delivery Drone System',
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
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
                                    labelText: 'Email',
                                    hintText: 'yourname@email.com',
                                    prefixIcon: Icons.email_outlined,
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => RegisterController.validateEmail(v, _selectedRole),
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
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
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
                                            label: 'Student',
                                            selected:
                                                _selectedRole == UserRole.user,
                                            onTap: () => setState(
                                              () => _selectedRole = UserRole.user,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _RoleTab(
                                            label: 'Faculty/Staff',
                                            selected:
                                                _selectedRole == UserRole.admin,
                                            onTap: () => setState(
                                              () => _selectedRole = UserRole.admin,
                                            ),
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
                            .fadeIn(delay: 200.ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),

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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
