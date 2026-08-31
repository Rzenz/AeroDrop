import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_list_tile.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/spring_switch.dart';
import '../../core/config/simulation_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final gutter = AppSpacing.pageGutter(context);

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: const CustomAppBar(title: 'Settings'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppSpacing.xs,
            gutter,
            AppSpacing.xxl,
          ),
          children: [
            if (kSimulationMode) ...[
              _buildRoleSwitcherTile(),
              const SizedBox(height: AppSpacing.lg),
            ],
            NeuTileGroup(
              label: 'Preferences',
              children: [
                NeuListTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark appearance',
                  subtitle: 'Always use the deep navy theme',
                  trailing: SpringSwitch(
                    value: themeMode == ThemeMode.dark,
                    semanticLabel: 'Dark appearance',
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      ref
                          .read(themeModeProvider.notifier)
                          .setTheme(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
                NeuListTile(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: _selectedLanguage,
                  onTap: _showLanguageSheet,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuTileGroup(
              label: 'Notifications',
              children: [
                NeuListTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Push alerts',
                  subtitle: 'Real-time flight updates',
                  iconColor: AppColors.accentText,
                  trailing: SpringSwitch(
                    value: _pushNotifications,
                    semanticLabel: 'Push alerts',
                    onChanged: (val) =>
                        setState(() => _pushNotifications = val),
                  ),
                ),
                NeuListTile(
                  icon: Icons.mark_email_unread_rounded,
                  title: 'Email alerts',
                  subtitle: 'Delivery receipts in your inbox',
                  iconColor: AppColors.accentText,
                  trailing: SpringSwitch(
                    value: _emailAlerts,
                    semanticLabel: 'Email alerts',
                    onChanged: (val) => setState(() => _emailAlerts = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuTileGroup(
              label: 'Security and legal',
              children: [
                NeuListTile(
                  icon: Icons.email_outlined,
                  title: 'Change email address',
                  onTap: _showChangeEmailDialog,
                ),
                NeuListTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Change password',
                  iconColor: AppColors.warning,
                  onTap: () => context.push('/user/profile/change-password'),
                ),
                NeuListTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/shared/privacy-policy'),
                ),
                NeuListTile(
                  icon: Icons.description_outlined,
                  title: 'Terms and conditions',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/shared/terms-conditions'),
                ),
                NeuListTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About AeroDrop',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/shared/about'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Developer-only role switch, shown when the app runs in simulation mode.
  Widget _buildRoleSwitcherTile() {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin == true;

    return NeuTileGroup(
      label: 'Simulation controls',
      children: [
        NeuListTile(
          icon: isAdmin
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline_rounded,
          title: 'Switch developer role',
          subtitle: 'Current role: ${isAdmin ? "Admin" : "User"}',
          iconColor: AppColors.accentText,
          trailing: Text(
            isAdmin ? 'To user' : 'To admin',
            style: AppTextStyles.label(
              fontSize: 12,
              color: AppColors.primaryText,
            ),
          ),
          onTap: () {
            HapticFeedback.mediumImpact();
            final target = isAdmin ? 'user' : 'admin';
            ref.read(authProvider.notifier).switchRole(target);
            context.go(target == 'admin' ? '/admin' : '/user');
          },
        ),
      ],
    );
  }

  void _showLanguageSheet() {
    const languages = ['English', 'Filipino', 'Cebuano'];
    showNeuSheet<void>(
      context,
      title: 'Language',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lang in languages) ...[
            NeuListTile(
              icon: Icons.translate_rounded,
              title: lang,
              showChevron: false,
              trailing: lang == _selectedLanguage
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    )
                  : null,
              onTap: () {
                setState(() => _selectedLanguage = lang);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  /// Email changes need confirmation at both addresses, so the copy says so
  /// before the user commits rather than after.
  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showNeuSheet<void>(
      context,
      title: 'Change email address',
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You will receive a confirmation link at both your current and '
              'your new address. Both must be verified before the change '
              'takes effect.',
              style: AppTextStyles.body(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuTextField(
              controller: emailController,
              labelText: 'New email address',
              hintText: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,4}$',
                ).hasMatch(val.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuButton(
              text: 'Send confirmation links',
              icon: Icons.send_rounded,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newEmail = emailController.text.trim().toLowerCase();
                Navigator.pop(context);
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(email: newEmail),
                  );
                  if (!mounted) return;
                  showNeuSnack(
                    context,
                    'Confirmation link sent to $newEmail and your current '
                    'email. Verify both to complete the change.',
                    tone: NeuToneKind.info,
                    duration: const Duration(seconds: 8),
                  );
                } catch (e) {
                  if (!mounted) return;
                  showNeuSnack(
                    context,
                    'Could not update your email: $e',
                    tone: NeuToneKind.error,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
