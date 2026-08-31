import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/logout_helper.dart';
import '../../core/widgets/neu_avatar.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_list_tile.dart';
import '../../core/widgets/neu_surface.dart';

/// The customer's account screen.
///
/// The header is an identity card on the canvas rather than the previous
/// full-bleed blue gradient with a glowing avatar. Every row below it is a
/// [NeuListTile], so this screen and the settings screen have identical row
/// metrics instead of two hand-built variants.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.name ?? 'User';
    final email = user?.email ?? '';
    final gutter = AppSpacing.pageGutter(context);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AppSpacing.md,
            gutter,
            AppSpacing.dockClearance(context),
          ),
          children: [
            Text('Profile', style: AppTextStyles.heading(fontSize: 24)),
            const SizedBox(height: AppSpacing.md),
            _IdentityCard(
              name: name,
              email: email,
              avatarUrl: user?.avatarUrl,
              role: user?.role,
              onTap: () => context.push('/user/profile/edit'),
            ),
            const SizedBox(height: AppSpacing.xl),
            NeuTileGroup(
              label: 'Account',
              children: [
                NeuListTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit profile details',
                  subtitle: 'Name, phone, and photo',
                  onTap: () => context.push('/user/profile/edit'),
                ),
                NeuListTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  onTap: () => context.push('/user/profile/change-password'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuTileGroup(
              label: 'Activity',
              children: [
                NeuListTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  iconColor: AppColors.accentText,
                  onTap: () => context.go('/user/notifications'),
                ),
                NeuListTile(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Order history',
                  iconColor: AppColors.accentText,
                  onTap: () => context.go('/user/orders'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            NeuTileGroup(
              label: 'Preferences and help',
              children: [
                NeuListTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/user/settings'),
                ),
                NeuListTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help and support',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/shared/help'),
                ),
                NeuListTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About AeroDrop',
                  iconColor: AppColors.textSecondary,
                  onTap: () => context.push('/shared/about'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            NeuListTile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              destructive: true,
              showChevron: false,
              onTap: () {
                HapticFeedback.mediumImpact();
                showLogoutConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar, name, email and role in one raised card.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.role,
    required this.onTap,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final String? role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      depth: NeuDepth.medium,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: 'Your profile: $name',
      child: Row(
        children: [
          NeuAvatar(name: name, imageUrl: avatarUrl, size: 62),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.heading(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (role != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _RoleTag(role: role!),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Role pill. Carries an icon as well as a colour so the role survives
/// greyscale and colour-blind viewing.
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (role) {
      'admin' => (
        AppColors.danger,
        Icons.admin_panel_settings_rounded,
        'Admin',
      ),
      'vendor' => (AppColors.accentText, Icons.storefront_rounded, 'Vendor'),
      _ => (AppColors.success, Icons.person_rounded, 'Customer'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.brPill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.readable(color), size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.label(
              fontSize: 10.5,
              color: AppColors.readable(color),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
