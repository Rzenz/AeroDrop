import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/controllers/login_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/widgets/entrance.dart';
import '../../core/widgets/neu_button.dart';
import 'widgets/auth_hero.dart';
import 'widgets/auth_switch_link.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/neu_surface.dart';
import '../../core/widgets/neu_back_button.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.asVendor = false});

  /// Set by `/login?role=vendor` from the welcome screen, and the starting
  /// value of the door the user can switch on this screen. It labels the
  /// screen for vendors — it does not change the credentials check or where
  /// the router sends them afterwards, both of which stay driven by the
  /// account's real role.
  final bool asVendor;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  /// Which door the user says they are coming in through. Local rather than
  /// read straight from the widget, because the button below the form flips
  /// it without a round trip through the router.
  late bool _asVendor = widget.asVendor;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadRememberedCredentials();
  }

  bool _reduceMotionApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotionApplied) return;
    _reduceMotionApplied = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? false;
      if (remember) {
        setState(() {
          _rememberMe = true;
          _emailController.text = prefs.getString('saved_email') ?? '';
        });
      } else {
        // Invalidate old session on startup if Remember Me is unchecked
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authProvider.notifier).logout();
        });
      }
    } catch (e) {
      debugPrint('Error loading remembered credentials: $e');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continueWithGoogle() {
    // Same honest stop as the welcome screen: no OAuth provider is wired to
    // Supabase, so the button says so instead of opening a sheet that cannot
    // finish. See WelcomeScreen._continueWithGoogle.
    showNeuSnack(
      context,
      'Google sign-in is not connected yet. Use your email and password.',
      tone: NeuToneKind.info,
    );
  }

  void _handleLogin() async {
    if (ref.read(authProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard to prevent animation jank during transition
      FocusScope.of(context).unfocus();

      final emailText = _emailController.text.trim().toLowerCase();
      final success = await ref
          .read(authProvider.notifier)
          .login(emailText, _passwordController.text);

      if (success && mounted) {
        // Persist or clear credentials based on Remember Me check
        try {
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('saved_email', emailText);
          } else {
            await prefs.setBool('remember_me', false);
            await prefs.remove('saved_email');
          }
        } catch (e) {
          debugPrint('Error saving remember me preferences: $e');
        }

        // Let the button state settle before navigating
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;

        context.go('/verification');
      } else if (!success && mounted) {
        final errorMsg =
            ref.read(authProvider).errorMessage ??
            'Login failed. Please try again.';
        showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final gutter = AppSpacing.pageGutter(context);
    final compact = MediaQuery.sizeOf(context).height < 720;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    // Keep the form at a comfortable measure on tablets and
                    // desktop instead of stretching it across the window.
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        AppSpacing.md,
                        gutter,
                        AppSpacing.xl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (Navigator.canPop(context))
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: NeuBackButton(),
                              ),
                            AuthHero(
                              progress: _intro,
                              compact: compact,
                              title: 'Sign in to AeroDrop',
                              subtitle: _asVendor
                                  ? 'Vendor sign-in'
                                  : 'Welcome back. Enter your details to '
                                        'continue.',
                            ),
                            SizedBox(
                              height: compact ? AppSpacing.lg : AppSpacing.xxl,
                            ),
                            ..._formBeats(authState.isLoading),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The form, one staggered beat per row.
  ///
  /// Returned as a list rather than wrapped in a card so the wells sit
  /// directly on the canvas. A raised card holding debossed fields stacks two
  /// depths inside one radius, and the inner and outer curves stop agreeing.
  List<Widget> _formBeats(bool isLoading) {
    // Indices, not hand-written intervals — reordering a row cannot desync the
    // stagger from the layout.
    var i = 0;
    Widget beat(Widget child) => Entrance.stagger(
      progress: _intro,
      index: i++,
      from: 0.26,
      child: child,
    );

    return [
      beat(
        NeuTextField(
          labelText: 'Email',
          hintText: 'yourname@email.com',
          prefixIcon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: LoginController.validateEmail,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      beat(
        NeuTextField(
          labelText: 'Password',
          hintText: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          validator: LoginController.validatePassword,
          autofillHints: const [AutofillHints.password],
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textTertiary,
              size: 20,
            ),
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      beat(_buildOptionsRow()),
      const SizedBox(height: AppSpacing.lg),
      beat(
        NeuButton(text: 'Login', isLoading: isLoading, onPressed: _handleLogin),
      ),
      const SizedBox(height: AppSpacing.md),
      beat(const _OrDivider()),
      const SizedBox(height: AppSpacing.md),
      beat(
        NeuButton(
          text: 'Continue with Google',
          variant: NeuButtonVariant.neutral,
          leading: SvgPicture.asset(
            'assets/svg/google_g.svg',
            width: 19,
            height: 19,
          ),
          onPressed: _continueWithGoogle,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      beat(
        NeuButton(
          text: _asVendor ? 'Login as customer' : 'Login as vendor',
          variant: NeuButtonVariant.neutral,
          icon: _asVendor ? Icons.person_rounded : Icons.storefront_rounded,
          // Flips back as well as forward. A one-way switch leaves a vendor
          // who tapped it by accident with no way out but the back button.
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _asVendor = !_asVendor);
          },
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      beat(const _RegisterLink()),
    ];
  }

  Widget _buildOptionsRow() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Semantics(
          toggled: _rememberMe,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NeuSurface(
                  style: _rememberMe ? NeuStyle.raised : NeuStyle.inset,
                  depth: NeuDepth.flat,
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  borderRadius: AppRadii.brXs,
                  color: _rememberMe
                      ? AppColors.accent
                      : AppColors.surfaceSunken,
                  child: _rememberMe
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.bgDark,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Remember me',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.push('/forgot-password'),
          child: Text(
            'Forgot password?',
            style: AppTextStyles.label(
              fontSize: 13,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

/// A hairline with "or" set into it, separating the credential path from the
/// provider path.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(
      child: Divider(color: AppColors.border, height: 1, thickness: 1),
    );

    return Row(
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('or', style: AppTextStyles.caption(fontSize: 12)),
        ),
        rule,
      ],
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink();

  @override
  Widget build(BuildContext context) => AuthSwitchLink(
    question: "Don't have an account?",
    action: 'Create account',
    onPressed: () => context.push('/register'),
  );
}
