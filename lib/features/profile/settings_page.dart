import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/spring_switch.dart';
import '../../core/config/simulation_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _darkMode = true;
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Settings'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
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
                          const SectionHeader(title: 'Simulation Controls', showAccentBar: true),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                            child: _buildRoleSwitcherTile(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Preference Category
                        const SectionHeader(title: 'Preferences', showAccentBar: true),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                icon: Icons.dark_mode_outlined,
                                title: 'Dark Color Mode',
                                subtitle: 'Always render deep navy theme',
                                value: _darkMode,
                                onChanged: (val) => setState(() => _darkMode = val),
                                activeColor: AppColors.primaryLight,
                              ),
                              _buildDivider(),
                              _buildLanguageTile(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Notifications Category
                        const SectionHeader(title: 'Notifications', showAccentBar: true),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                icon: Icons.notifications_active_outlined,
                                title: 'Push Alerts',
                                subtitle: 'Receive real-time flight updates',
                                value: _pushNotifications,
                                onChanged: (val) => setState(() => _pushNotifications = val),
                                activeColor: AppColors.accent,
                              ),
                              _buildDivider(),
                              _buildSwitchTile(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email Alerts',
                                subtitle: 'Get delivery receipts in inbox',
                                value: _emailAlerts,
                                onChanged: (val) => setState(() => _emailAlerts = val),
                                activeColor: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Security & Privacy Category
                        const SectionHeader(title: 'Security & Legal', showAccentBar: true),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Column(
                            children: [
                              _buildNavigationTile(
                                icon: Icons.lock_reset_rounded,
                                title: 'Change Password',
                                color: AppColors.warning,
                                onTap: () => context.push('/user/profile/change-password'),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.privacy_tip_outlined,
                                title: 'Privacy Policy',
                                color: AppColors.primaryLight,
                                onTap: () => context.push('/shared/privacy-policy'),
                              ),
                              _buildDivider(),
                              _buildNavigationTile(
                                icon: Icons.description_outlined,
                                title: 'Terms & Conditions',
                                color: AppColors.success,
                                onTap: () => context.push('/shared/terms-conditions'),
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
    return Divider(
      color: AppColors.borderDark.withValues(alpha: 0.5),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        title: Text(
          title,
          style: AppTextStyles.title(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.textSecondaryDark),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.language_rounded, color: Colors.white, size: 18),
        ),
        title: Text(
          'Language',
          style: AppTextStyles.title(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          'Change app localization settings',
          style: AppTextStyles.body(fontSize: 11.5, color: AppColors.textSecondaryDark),
        ),
        trailing: DropdownButton<String>(
          value: _selectedLanguage,
          dropdownColor: AppColors.cardDark,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent),
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English', style: TextStyle(color: Colors.white, fontSize: 13))),
            DropdownMenuItem(value: 'Spanish', child: Text('Español', style: TextStyle(color: Colors.white, fontSize: 13))),
            DropdownMenuItem(value: 'Filipino', child: Text('Filipino', style: TextStyle(color: Colors.white, fontSize: 13))),
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
          style: AppTextStyles.title(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark, size: 20),
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
    final isAdmin = user?.role == UserRole.admin;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded,
          color: AppColors.accent,
          size: 24,
        ),
        title: Text(
          'Switch Developer Role',
          style: AppTextStyles.title(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          'Current Role: ${user?.role == UserRole.admin ? "Admin" : "User"}',
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: AppColors.textSecondaryDark,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.borderDark, width: 1.5),
          ),
          child: Text(
            isAdmin ? 'Switch to User' : 'Switch to Admin',
            style: AppTextStyles.label(
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ),
        onTap: () {
          HapticFeedback.mediumImpact();
          final targetRole = isAdmin ? UserRole.user : UserRole.admin;
          ref.read(authProvider.notifier).switchRole(targetRole);
          context.go(targetRole == UserRole.admin ? '/admin' : '/user');
        },
      ),
    );
  }
}
