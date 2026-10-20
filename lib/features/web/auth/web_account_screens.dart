import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/logout_helper.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/widgets/neu_feedback.dart';
import '../../auth/widgets/auth_kit.dart';
import '../web_tokens.dart';

/// The website's short account tasks — reset a password, add the missing
/// phone number, wait for vendor approval — each as one card in the middle
/// of the sign-in page's photograph, like the code-entry screens.

// ─── Forgot password ─────────────────────────────────────────────────────────

class WebForgotPasswordScreen extends ConsumerStatefulWidget {
  const WebForgotPasswordScreen({super.key});

  @override
  ConsumerState<WebForgotPasswordScreen> createState() =>
      _WebForgotPasswordScreenState();
}

class _WebForgotPasswordScreenState
    extends ConsumerState<WebForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_loading || !_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    final n = ref.read(authProvider.notifier);
    final googleOnly = await n.checkIsGoogleOnlyAccount(email);
    final ok = await n.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      showNeuSnack(
        context,
        ref.read(authProvider).errorMessage ??
            'The reset code could not be sent. Try again.',
        tone: NeuToneKind.error,
      );
      return;
    }
    if (googleOnly) {
      showNeuSnack(
        context,
        'This account signs in with Google. You can keep doing that, or use '
        'the code to set a password.',
        tone: NeuToneKind.info,
      );
    }
    context.push(
      '/email-sent',
      extra: <String, String>{
        'email': email,
        'type': 'reset',
        if (googleOnly) 'is_google_only': 'true',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthCenterShell(
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeading(
              title: 'Reset your password',
              subtitle: 'We email you a code to set a new one.',
              inCard: true,
            ),
            const SizedBox(height: 24),
            AuthField(
              labelText: 'Email',
              hintText: 'yourname@email.com',
              prefixIcon: Icons.mail_outline_rounded,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            AuthButton(
              text: 'Send the code',
              isLoading: _loading,
              onPressed: _send,
            ),
            const SizedBox(height: 14),
            Center(
              child: AuthTextLink(
                label: 'Back to sign in',
                onTap: () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Complete profile ────────────────────────────────────────────────────────

class WebCompleteProfileScreen extends ConsumerStatefulWidget {
  const WebCompleteProfileScreen({super.key});

  @override
  ConsumerState<WebCompleteProfileScreen> createState() =>
      _WebCompleteProfileScreenState();
}

class _WebCompleteProfileScreenState
    extends ConsumerState<WebCompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    String phone;
    try {
      phone = normalizePhoneNumber(_phone.text.trim());
    } catch (_) {
      showNeuSnack(
        context,
        'Enter a Philippine mobile number, like 09171234567.',
        tone: NeuToneKind.error,
      );
      return;
    }
    final user = ref.read(authProvider).user;
    final session =
        SupabaseService.isConfigured &&
        SupabaseService.client.auth.currentSession != null;
    if (user == null || !session) {
      showNeuSnack(
        context,
        'Your session ended. Sign in again.',
        tone: NeuToneKind.error,
      );
      context.go('/login');
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(authProvider.notifier)
        .updateProfile(
          user.fullName.isNotEmpty ? user.fullName : 'Customer',
          user.email,
          phoneNumber: phone,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showNeuSnack(
        context,
        ref.read(authProvider).errorMessage ?? 'The number could not be saved.',
        tone: NeuToneKind.error,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    showNeuSnack(
      context,
      'All set. Welcome to AeroDrop.',
      tone: NeuToneKind.success,
    );
    final u = ref.read(authProvider).user;
    if (u == null) return;
    context.go(
      u.isAdmin
          ? '/admin'
          : (u.isVendor
                ? '/vendor'
                : (u.isPendingVendor ? '/account-pending' : '/user')),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final first = (user?.fullName ?? '').trim().split(' ').first;
    return AuthCenterShell(
      onBack: _signOut,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(
              title: first.isEmpty
                  ? 'One more thing'
                  : 'One more thing, $first',
              subtitle:
                  'Add a mobile number so the canteen and the drone crew can '
                  'reach you about a delivery.',
              inCard: true,
            ),
            const SizedBox(height: 24),
            AuthField(
              labelText: 'Mobile number',
              hintText: '09171234567',
              prefixIcon: Icons.phone_outlined,
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: const [PhoneInputFormatter()],
              validator: (v) => isValidPhoneNumber(v ?? '')
                  ? null
                  : 'Enter a mobile number like 09171234567',
            ),
            const SizedBox(height: 22),
            AuthButton(text: 'Continue', isLoading: _saving, onPressed: _save),
            const SizedBox(height: 14),
            Center(
              child: AuthTextLink(
                label: 'Sign out instead',
                color: WebInk.textSoft,
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Account pending ─────────────────────────────────────────────────────────

/// A vendor application waiting for an administrator. The app's screen has
/// a "Contact administrator" button that reports a request as sent without
/// sending one; this page says plainly what happens next instead.
class WebAccountPendingScreen extends ConsumerWidget {
  const WebAccountPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final store = user?.businessName ?? 'Your store';
    final sent = user?.createdAt;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: WebType.body())),
          Text(value, style: WebType.action(color: WebInk.text)),
        ],
      ),
    );

    return AuthCenterShell(
      onBack: () => showLogoutConfirmation(context, ref),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 38,
            color: WebInk.accent,
          ),
          const SizedBox(height: 14),
          const AuthHeading(
            title: 'Your application is in review',
            subtitle:
                'An administrator checks every new store before it can sell. '
                'You can sign in to your store as soon as it is approved.',
            inCard: true,
          ),
          const SizedBox(height: 20),
          AuthWell(
            label: 'Application',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  line('Store', store),
                  line('Status', 'Waiting for review'),
                  line(
                    'Sent',
                    sent == null
                        ? '—'
                        : '${sent.day}/${sent.month}/${sent.year}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          AuthButton(
            text: 'Sign out',
            icon: Icons.logout_rounded,
            variant: AuthButtonVariant.secondary,
            onPressed: () => showLogoutConfirmation(context, ref),
          ),
        ],
      ),
    );
  }
}
