import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/neu_feedback.dart';
import '../web_tokens.dart';
import '../../auth/presentation/controllers/login_controller.dart';
import '../../auth/widgets/auth_kit.dart';

class WebLoginScreen extends ConsumerStatefulWidget {
  const WebLoginScreen({super.key, this.asVendor = false});

  /// Set by `/login?role=vendor` from the welcome screen, and the starting
  /// value of the door the user can switch on this screen. It labels the
  /// screen for vendors — it does not change the credentials check or where
  /// the router sends them afterwards, both of which stay driven by the
  /// account's real role.
  final bool asVendor;

  @override
  ConsumerState<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends ConsumerState<WebLoginScreen> {
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
    _loadRememberedCredentials();
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
      }
    } catch (e) {
      debugPrint('Error loading remembered credentials: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    HapticFeedback.lightImpact();
    if (_asVendor) {
      showNeuSnack(
        context,
        'Google sign-in creates a customer account. To sell on AeroDrop, register a vendor account with your store details.',
        tone: NeuToneKind.info,
      );
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.isLoading) return;

    try {
      final success = await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;

      if (!success) {
        final err = ref.read(authProvider).errorMessage;
        if (err != null && err.isNotEmpty) {
          showNeuSnack(context, err, tone: NeuToneKind.error);
        }
      } else {
        final user = ref.read(authProvider).user;
        if (user != null) {
          if (user.phoneNumber == null || user.phoneNumber!.trim().isEmpty) {
            context.go('/complete-profile');
          } else if (user.isAdmin) {
            context.go('/admin');
          } else if (user.isVendor) {
            context.go('/vendor');
          } else if (user.isPendingVendor) {
            context.go('/account-pending');
          } else {
            context.go('/user');
          }
        }
      }
    } catch (e) {
      debugPrint('Error during Google sign-in: $e');
      if (mounted) {
        showNeuSnack(
          context,
          formatAuthErrorMessage(e),
          tone: NeuToneKind.error,
        );
      }
    }
  }

  void _handleLogin() async {
    if (ref.read(authProvider).isLoading) return;
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard to prevent animation jank during transition
      FocusScope.of(context).unfocus();

      final emailText = _emailController.text.trim().toLowerCase();
      final expectedRole = _asVendor ? 'vendor' : 'user';
      final success = await ref
          .read(authProvider.notifier)
          .login(
            emailText,
            _passwordController.text,
            expectedRole: expectedRole,
          );

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

        final user = ref.read(authProvider).user;
        if (user != null && user.isAdmin) {
          context.go('/admin');
        } else {
          context.go('/verification');
        }
      } else if (!success && mounted) {
        final authState = ref.read(authProvider);
        if (authState.pendingEmail != null &&
            authState.requiresVerification &&
            authState.user == null) {
          final message =
              authState.errorMessage ??
              "Your email isn't verified yet. We sent you a new code.";
          showNeuSnack(context, message, tone: NeuToneKind.info);
          context.push(
            '/email-sent',
            extra: <String, String>{
              'email': authState.pendingEmail!,
              'role': expectedRole,
              'type': 'verification',
            },
          );
          return;
        }
        final errorMsg =
            authState.errorMessage ?? 'Login failed. Please try again.';
        showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    // Each row's position in the entrance, by index, so reordering rows
    // cannot desync the stagger from the layout.
    var i = 0;
    Widget row(Widget child) => child.authReveal(context, i++);

    return AuthShell(
      vendor: _asVendor,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(
                AuthHeading(
                  title: _asVendor ? 'Vendor sign-in' : 'Sign in',
                  subtitle: _asVendor
                      ? 'Use the email and password your store registered '
                            'with.'
                      : 'Welcome back. Enter your details to continue.',
                ),
              ),
              SizedBox(height: context.authGap(24)),
              // Which door. A switch at the top rather than a button at the
              // bottom, because it decides what the rest of the screen says.
              // It labels the screen only: the credentials check and the
              // redirect after sign-in follow the account's real role.
              row(
                AuthSegmented(
                  options: const ['Customer', 'Vendor'],
                  icons: const [
                    Icons.person_outline_rounded,
                    Icons.storefront_outlined,
                  ],
                  selectedIndex: _asVendor ? 1 : 0,
                  onSelected: (i) => setState(() => _asVendor = i == 1),
                ),
              ),
              SizedBox(height: context.authGap(24)),
              row(
                AuthField(
                  labelText: 'Email',
                  hintText: 'yourname@email.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: LoginController.validateEmail,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
              ),
              SizedBox(height: context.authGap(18)),
              row(
                AuthField(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: LoginController.validatePassword,
                  autofillHints: const [AutofillHints.password],
                  suffixIcon: AuthObscureToggle(
                    obscured: _obscurePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              SizedBox(height: context.authGap(6)),
              row(
                Row(
                  children: [
                    Expanded(
                      child: AuthCheck(
                        value: _rememberMe,
                        label: 'Remember me',
                        onChanged: (v) => setState(() => _rememberMe = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right-aligned, and allowed to wrap rather than
                    // overflow at narrow widths and large text sizes.
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AuthTextLink(
                          label: 'Forgot password?',
                          onTap: () => context.push('/forgot-password'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.authGap(18)),
              row(
                AuthButton(
                  text: 'Sign in',
                  isLoading: isLoading,
                  onPressed: _handleLogin,
                ),
              ),
              SizedBox(height: context.authGap(20)),
              if (_asVendor)
                // Google is a customer door: it creates a customer account.
                // Saying so here replaces a button that would only explain
                // itself after being pressed.
                row(
                  Text(
                    'Vendors sign in with email and password. Google sign-in '
                    'creates a customer account.',
                    textAlign: TextAlign.center,
                    style: WebType.meta(
                      color: WebInk.textSoft,
                    ).copyWith(fontSize: 13, height: 1.5),
                  ),
                )
              else ...[
                row(const AuthOrDivider()),
                SizedBox(height: context.authGap(20)),
                row(
                  AuthButton(
                    text: 'Continue with Google',
                    variant: AuthButtonVariant.secondary,
                    leading: SvgPicture.asset(
                      'assets/svg/google_g.svg',
                      width: 18,
                      height: 18,
                    ),
                    onPressed: _continueWithGoogle,
                  ),
                ),
              ],
              SizedBox(height: context.authGap(28)),
              row(const WebRule()),
              SizedBox(height: context.authGap(20)),
              row(
                AuthSwitchPrompt(
                  question: _asVendor
                      ? 'New to selling on AeroDrop?'
                      : "Don't have an account?",
                  action: _asVendor ? 'Apply as a vendor' : 'Create one',
                  onTap: () => context.push(
                    _asVendor ? '/register?role=vendor' : '/register',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
