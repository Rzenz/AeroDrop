import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final deliveries = ref.watch(deliveryProvider);
    final name = user?.name ?? 'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Parallax Header
          SliverAppBar(
            expandedHeight: 250,
            backgroundColor: AppColors.bgDark,
            elevation: 0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1565C0), AppColors.bgDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Avatar & Name content
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Pulsing Avatar Glow
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.accentGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: AppTextStyles.title(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.bgDark,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .scale(curve: Curves.elasticOut, duration: 600.ms),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: AppTextStyles.heading(fontSize: 22),
                        ).animate().fadeIn(delay: 150.ms),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: AppTextStyles.body(
                            fontSize: 13.5,
                            color: AppColors.textSecondaryDark,
                          ),
                        ).animate().fadeIn(delay: 250.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Horizontal Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _StatItem(
                    val: '${deliveries.length}',
                    lbl: 'Dispatches',
                    color: AppColors.primaryLight,
                    icon: Icons.local_shipping_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatItem(
                    val: '${deliveries.where((d) => d.status == DeliveryStatus.delivered).length}',
                    lbl: 'Completed',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
                  const SizedBox(width: 12),
                  const _StatItem(
                    val: '4.9 ★',
                    lbl: 'Rating',
                    color: AppColors.accent,
                    icon: Icons.star_rounded,
                  ),
                ],
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),
            ),
          ),

          // Menu List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileSection(
                  title: 'ACCOUNT CREDENTIALS',
                  items: [
                    _ProfileMenuItem(
                      icon: Icons.edit_rounded,
                      label: 'Edit Profile Details',
                      color: AppColors.primaryLight,
                      onTap: () => context.push('/user/profile/edit'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change Password',
                      color: AppColors.primaryLight,
                      onTap: () => context.push('/user/profile/change-password'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileSection(
                  title: 'ACTIVITY LOGS',
                  items: [
                    _ProfileMenuItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      color: AppColors.accent,
                      onTap: () => context.go('/user/notifications'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.history_toggle_off_rounded,
                      label: 'Delivery History Logs',
                      color: AppColors.accent,
                      onTap: () => context.go('/user/history'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileSection(
                  title: 'PREFERENCES & HELP',
                  items: [
                    _ProfileMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'System Settings',
                      color: AppColors.textSecondaryDark,
                      onTap: () => context.push('/user/settings'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support Desk',
                      color: AppColors.textSecondaryDark,
                      onTap: () => context.push('/shared/help'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'About AeroDrop System',
                      color: AppColors.textSecondaryDark,
                      onTap: () => context.push('/shared/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Sign Out Card
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sign Out Session',
                          style: AppTextStyles.title(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String val;
  final String lbl;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.val,
    required this.lbl,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              val,
              style: AppTextStyles.display(
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lbl,
              style: AppTextStyles.label(
                fontSize: 9,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileMenuItem> items;

  const _ProfileSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: AppTextStyles.label(
              fontSize: 11,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(24),
          borderGradient: const LinearGradient(
            colors: [Colors.white12, Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  item,
                  if (i < items.length - 1)
                    const Divider(
                      height: 1,
                      indent: 52,
                      endIndent: 16,
                      color: AppColors.borderDark,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.title(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
