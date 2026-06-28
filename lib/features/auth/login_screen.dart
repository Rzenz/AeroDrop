import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'presentation/controllers/login_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'john.doe@uclm.edu');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  late AnimationController _bgRotateController;

  @override
  void initState() {
    super.initState();
    _bgRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgRotateController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (ref.read(authProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard to prevent animation jank during transition
      FocusScope.of(context).unfocus();

      final success = await ref.read(authProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
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
          // Background: Editorial rich gradient
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

          // Ambient blue-yellow rotating radar
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

          // Ambient yellow glow bottom-left
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

                            // Header Section
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
                                      'UCLM Drone Fleet Command',
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
                                        color: AppColors.accent.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.flight_takeoff_rounded,
                                    size: 26,
                                    color: AppColors.bgDark,
                                  ),
                                )
                                    .animate()
                                    .scale(
                                      duration: 600.ms,
                                      curve: Curves.elasticOut,
                                    )
                                    .fadeIn(),
                              ],
                            ),

                            const SizedBox(height: 40),

                            // Glassmorphism Card
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
                                    'Sign In',
                                    style: AppTextStyles.heading(fontSize: 22),
                                  ),
                                  const SizedBox(height: 24),
                                  CustomTextField(
                                    labelText: 'University Email',
                                    hintText: 'yourname@uclm.edu',
                                    prefixIcon: Icons.email_outlined,
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: LoginController.validateEmail,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 20),
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
                                    validator: LoginController.validatePassword,
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
                                          color: AppColors.accentLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GradientButton(
                                    text: 'Log In',
                                    isLoading: authState.isLoading,
                                    onPressed: _handleLogin,
                                    icon: Icons.login_rounded,
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                            const SizedBox(height: 32),

                            // Register Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "New to the fleet?",
                                  style: AppTextStyles.body(
                                    fontSize: 14,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/register'),
                                  child: Text(
                                    'Create Account',
                                    style: AppTextStyles.body(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentLight,
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 300.ms),

                            const SizedBox(height: 24),

                            // Quick Access Sessions
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Text(
                                    'QUICK ACCESS SESSIONS',
                                    style: AppTextStyles.label(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 350.ms),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _QuickAccessButton(
                                        title: 'User Portal',
                                        subtitle: 'john.doe',
                                        icon: Icons.person_outline_rounded,
                                        accentColor: AppColors.primaryLight,
                                        onTap: () {
                                          _emailController.text = 'john.doe@uclm.edu';
                                          _passwordController.text = 'password123';
                                          _handleLogin();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _QuickAccessButton(
                                        title: 'Command Deck',
                                        subtitle: 'admin.portal',
                                        icon: Icons.admin_panel_settings_outlined,
                                        accentColor: AppColors.accent,
                                        onTap: () {
                                          _emailController.text = 'admin.portal@uclm.edu';
                                          _passwordController.text = 'admin123';
                                          _handleLogin();
                                        },
                                      ),
                                    ),
                                  ],
                                ).animate().fadeIn(delay: 400.ms).slideY(
                                      begin: 0.08,
                                      end: 0,
                                      curve: Curves.easeOutCubic,
                                    ),
                                const SizedBox(height: 32),
                              ],
                            ),
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

class _QuickAccessButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_QuickAccessButton> createState() => _QuickAccessButtonState();
}

class _QuickAccessButtonState extends State<_QuickAccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.title(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
