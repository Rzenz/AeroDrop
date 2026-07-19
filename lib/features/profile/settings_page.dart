import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/section_header.dart';
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

    final isDark = AppTheme.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: 'Settings'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0F243A), AppColors.bgDark]
                : const [Color(0xFFE6EFFF), AppColors.bgLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // Settings List
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (kSimulationMode) ...[
                          const SectionHeader(
                            title: 'Simulation Controls',
                            showAccentBar: true,
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 16,
                            ),
                            child: _buildRoleSwitcherTile(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Preference Category
                        const SectionHeader(
                          title: 'Preferences',
                          showAccentBar: true,
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                icon: Icons.dark_mode_outlined,
                                title: 'Dark Color Mode',
                                subtitle: 'Always render deep navy theme',
                                value: themeMode == ThemeMode.dark,
                                onChanged: (val) {
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setTheme(
                                        val ? ThemeMode.dark : ThemeMode.light,
                                      );
                                },
                                activeColor: AppColors.primaryLight,
                              ),
                              _buildDivider(),
                              _buildLanguageTile(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Notifications Category
                        const SectionHeader(
                          title: 'Notifications',
                          showAccentBar: true,
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                icon: Icons.notifications_active_outlined,
                                title: 'Push Alerts',
                                subtitle: 'Receive real-time flight updates',
                                value: _pushNotifications,
                                onChanged: (val) =>
                                    setState(() => _pushNotifications = val),
                                activeColor: AppColors.accent,
                              ),
                              _buildDivider(),
                              _buildSwitchTile(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email Alerts',
                                subtitle: 'Get delivery receipts in inbox',
                                value: _emailAlerts,
                                onChanged: (val) =>
                                    setState(() => _emailAlerts = val),
                                activeColor: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Security & Privacy Category
                        const SectionHeader(
                          title: 'Security & Legal',
                          showAccentBar: true,
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          child: Column(
                            children: [
                              _buildNavigationTile(
                                icon: Icons.email_outlined,
                                title: 'Change Email Address',
                                color: AppColors.accent,
                                onTap: () => _showChangeEmailDialog(),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.lock_reset_rounded,
                                title: 'Change Password',
                                color: AppColors.warning,
                                onTap: () => context.push(
                                  '/user/profile/change-password',
                                ),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.privacy_tip_outlined,
                                title: 'Privacy Policy',
                                color: AppColors.primaryLight,
                                onTap: () =>
                                    context.push('/shared/privacy-policy'),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.description_outlined,
                                title: 'Terms & Conditions',
                                color: AppColors.success,
                                onTap: () =>
                                    context.push('/shared/terms-conditions'),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.info_outline_rounded,
                                title: 'About AeroDrop',
                                color: AppColors.accent,
                                onTap: () => context.push('/shared/about'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = AppTheme.isDarkMode;
    return Divider(
      color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(
        alpha: 0.5,
      ),
      indent: 56,
      endIndent: 16,
      height: 1,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    final isDark = AppTheme.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primary).withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.title(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        trailing: SpringSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
        ),
      ),
    );
  }

  Widget _buildLanguageTile() {
    final isDark = AppTheme.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primary).withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.language_rounded,
            color: isDark ? Colors.white : AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          'Language',
          style: AppTextStyles.title(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Text(
          'Change app localization settings',
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        trailing: DropdownButton<String>(
          value: _selectedLanguage,
          dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          underline: const SizedBox(),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.accent,
          ),
          items: [
            DropdownMenuItem(
              value: 'English',
              child: Text(
                'English',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 13,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'Spanish',
              child: Text(
                'Español',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 13,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'Filipino',
              child: Text(
                'Filipino',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.lightImpact();
              setState(() => _selectedLanguage = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: AppTextStyles.title(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          size: 20,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }

  Widget _buildRoleSwitcherTile() {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isAdmin = user?.isAdmin == true;
    final isDark = AppTheme.isDarkMode;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isAdmin
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline_rounded,
          color: AppColors.accent,
          size: 24,
        ),
        title: Text(
          'Switch Developer Role',
          style: AppTextStyles.title(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Text(
          'Current Role: ${user?.isAdmin == true ? "Admin" : "User"}',
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Text(
            isAdmin ? 'Switch to User' : 'Switch to Admin',
            style: AppTextStyles.label(
              fontSize: 10,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ),
        onTap: () {
          HapticFeedback.mediumImpact();
          final targetRole = isAdmin ? 'user' : 'admin';
          ref.read(authProvider.notifier).switchRole(targetRole);
          context.go(targetRole == 'admin' ? '/admin' : '/user');
        },
      ),
    );
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Email Address',
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your new email address. You will receive confirmation links at both your old and new email addresses to complete the switch.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'New Email Address',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newEmail = emailController.text.trim().toLowerCase();
                  Navigator.pop(ctx);
                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(email: newEmail),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Confirmation link sent to $newEmail and your current email. Please verify both to complete the change.',
                          ),
                          backgroundColor: AppColors.info,
                          duration: const Duration(seconds: 8),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update email: $e'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text(
                'Change Email',
                style: TextStyle(
                  color: AppColors.bgDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
