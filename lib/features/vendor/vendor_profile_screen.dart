import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/logout_helper.dart';

class VendorProfileScreen extends ConsumerStatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  ConsumerState<VendorProfileScreen> createState() =>
      _VendorProfileScreenState();
}

class _VendorProfileScreenState extends ConsumerState<VendorProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    try {
      final image = await ImageUtils.pickAndCropImage(
        source: ImageSource.gallery,
        title: 'Crop Business Logo',
      );
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          showNeuSnack(
            context,
            'Image must be less than 2MB',
            tone: NeuToneKind.error,
          );
        }
        return;
      }

      setState(() => _uploadingAvatar = true);
      final success = await ref.read(authProvider.notifier).updateAvatar(image);
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        showNeuSnack(
          context,
          success ? 'Avatar updated!' : 'Failed to upload avatar.',
          tone: NeuToneKind.success,
        );
      }
    } catch (e) {
      debugPrint('Avatar change error: $e');
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _confirmLogout() async {
    await showLogoutConfirmation(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.base,
        body: Center(
          child: Text(
            'No active session.',
            style: AppTextStyles.body(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    final locationsAsync = ref.watch(campusLocationsProvider);
    final locationName = locationsAsync.when(
      data: (list) {
        final loc = list
            .where((l) => l.id == user.campusLocationId)
            .firstOrNull;
        return loc?.name ?? 'UCLM Campus';
      },
      loading: () => '...',
      error: (err, stack) => 'UCLM Campus',
    );

    final initials = user.businessName != null && user.businessName!.isNotEmpty
        ? user.businessName!.substring(0, 1).toUpperCase()
        : (user.fullName.isNotEmpty
              ? user.fullName.substring(0, 1).toUpperCase()
              : 'V');

    final businessName = user.businessName ?? user.fullName;

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(title: 'My Profile'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // Avatar + Business Name
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(20),
                          image: user.avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(user.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF6B35,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _uploadingAvatar
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : user.avatarUrl == null
                            ? Text(
                                initials,
                                style: AppTextStyles.heading(
                                  fontSize: 28,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.bgDark,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: AppColors.bgDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  businessName,
                  style: AppTextStyles.heading(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.isVendor
                        ? '● Active Vendor'
                        : user.isPendingVendor
                        ? '⏳ Pending Approval'
                        : '● User',
                    style: AppTextStyles.label(
                      fontSize: 12,
                      color: user.isVendor
                          ? AppColors.success
                          : user.isPendingVendor
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 28),

          // Vendor Information
          _InfoCard(
            title: 'Vendor Information',
            icon: Icons.storefront_outlined,
            items: [
              _Item(label: 'Owner', value: user.fullName),
              _Item(label: 'Location', value: locationName),
              _Item(label: 'Email', value: user.email),
              _Item(label: 'Phone', value: user.phoneNumber ?? 'Not provided'),
              if (user.businessDescription != null &&
                  user.businessDescription!.isNotEmpty)
                _Item(label: 'Description', value: user.businessDescription!),
            ],
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 16),

          _InfoCard(
            title: 'Category',
            icon: Icons.category_outlined,
            items: [],
            child:
                (user.businessCategory == null ||
                    user.businessCategory!.trim().isEmpty)
                ? Text(
                    'Not provided',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          user.businessCategory!,
                          style: AppTextStyles.caption(
                            fontSize: 12,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
          ).animate().fadeIn(delay: 130.ms),
          const SizedBox(height: 16),

          // Quick Links
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => context.push('/vendor/profile/edit'),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => context.push('/shared/help'),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.article_outlined,
            label: 'Terms & Conditions',
            onTap: () => context.push('/shared/terms-conditions'),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.info_outline_rounded,
            label: 'About AeroDrop',
            onTap: () => context.push('/shared/about'),
          ),
          const SizedBox(height: 24),

          // Logout — padded so it's above the bottom nav bar
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _confirmLogout();
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: Text(
              'Log Out',
              style: AppTextStyles.subHead(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final String label;
  final String value;
  const _Item({required this.label, required this.value});
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Item> items;
  final Widget? child;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.items,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.subHead(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (child != null) ...[child!, const SizedBox(height: 8)],
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      item.label,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.value,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.base,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
