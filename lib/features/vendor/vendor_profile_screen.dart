import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../mock_data/vendors_mock.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  static final _vendor = mockVendors.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Vendor Profile', style: AppTextStyles.subHead(fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit profile (coming soon)'), behavior: SnackBarBehavior.floating),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Logo + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _vendor.logoColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _vendor.logoColor.withValues(alpha: 0.4), blurRadius: 20)],
                  ),
                  alignment: Alignment.center,
                  child: Text(_vendor.logoInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                ),
                const SizedBox(height: 12),
                Text(_vendor.businessName, style: AppTextStyles.heading(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('● Active Vendor', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 28),

          // Info section
          _InfoCard(
            title: 'Business Information',
            icon: Icons.storefront_outlined,
            items: [
              _Item(label: 'Owner', value: _vendor.ownerName),
              _Item(label: 'Building', value: _vendor.building),
              _Item(label: 'Email', value: _vendor.email),
              _Item(label: 'Phone', value: _vendor.phone),
              _Item(label: 'Rating', value: '${_vendor.rating} ⭐'),
              _Item(label: 'Total Orders', value: '${_vendor.totalOrders}'),
            ],
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 16),

          // Categories
          _InfoCard(
            title: 'Categories',
            icon: Icons.category_outlined,
            items: [],
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vendor.categories.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Text(c, style: const TextStyle(color: AppColors.primaryLight, fontSize: 12)),
              )).toList(),
            ),
          ).animate().fadeIn(delay: 130.ms),
          const SizedBox(height: 16),

          // Actions
          _ActionTile(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => context.push('/shared/help')),
          const SizedBox(height: 8),
          _ActionTile(icon: Icons.article_outlined, label: 'Terms & Conditions', onTap: () => context.push('/shared/terms-conditions')),
          const SizedBox(height: 8),
          _ActionTile(icon: Icons.info_outline_rounded, label: 'About AeroDrop', onTap: () => context.push('/shared/about')),
          const SizedBox(height: 16),

          // Logout
          OutlinedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  const _InfoCard({required this.title, required this.icon, required this.items, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.subHead(fontSize: 14, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          child ?? const SizedBox.shrink(),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(item.label, style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark))),
                const SizedBox(width: 8),
                Expanded(child: Text(item.value, style: AppTextStyles.body(fontSize: 13, color: Colors.white))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardDark,
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
              Expanded(child: Text(label, style: AppTextStyles.body(fontSize: 14, color: Colors.white))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
