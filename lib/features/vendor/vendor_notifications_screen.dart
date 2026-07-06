import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class VendorNotificationItem {
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color iconColor;
  final bool isUnread;

  const VendorNotificationItem({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isUnread = false,
  });
}

class VendorNotificationsScreen extends StatelessWidget {
  const VendorNotificationsScreen({super.key});

  static final List<VendorNotificationItem> _today = [
    const VendorNotificationItem(
      title: 'New Order Received',
      description: 'Order #AD-9842 from Juan dela Cruz (2 items · ₱320.00)',
      time: '10 mins ago',
      icon: Icons.receipt_long_rounded,
      iconColor: AppColors.primaryLight,
      isUnread: true,
    ),
    const VendorNotificationItem(
      title: 'Drone Assigned to Order #AD-9838',
      description: 'Drone Sparrow (DR-09) has been scheduled to pick up the package.',
      time: '45 mins ago',
      icon: Icons.flight_takeoff_rounded,
      iconColor: AppColors.accent,
      isUnread: true,
    ),
    const VendorNotificationItem(
      title: 'Payment Confirmed',
      description: 'GCash payment of ₱180.00 received for order #AD-9838.',
      time: '1 hr ago',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: AppColors.success,
    ),
  ];

  static final List<VendorNotificationItem> _yesterday = [
    const VendorNotificationItem(
      title: 'Order Completed',
      description: 'Order #AD-9831 was successfully delivered to Science Building.',
      time: 'Yesterday, 3:15 PM',
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
    ),
    const VendorNotificationItem(
      title: 'Low Stock Alert',
      description: '"Classic Beef Shawarma" stock is down to 2 units.',
      time: 'Yesterday, 11:20 AM',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warning,
    ),
    const VendorNotificationItem(
      title: 'Order Cancelled',
      description: 'Order #AD-9828 was cancelled by the customer.',
      time: 'Yesterday, 9:40 AM',
      icon: Icons.cancel_outlined,
      iconColor: AppColors.danger,
    ),
  ];

  static final List<VendorNotificationItem> _earlier = [
    const VendorNotificationItem(
      title: 'Weekly Payout Initiated',
      description: 'A transfer of ₱8,450.00 to your merchant GCash is in progress.',
      time: 'July 5, 2026',
      icon: Icons.monetization_on_rounded,
      iconColor: AppColors.success,
    ),
    const VendorNotificationItem(
      title: 'New Store Promo Active',
      description: 'Your "Free Drone Delivery on orders above ₱350" promo is now live.',
      time: 'July 3, 2026',
      icon: Icons.campaign_rounded,
      iconColor: AppColors.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Notification Center',
          style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white70),
            tooltip: 'Mark all as read',
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All notifications marked as read.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (_today.isNotEmpty) ...[
            _buildSectionHeader('TODAY'),
            ..._today.asMap().entries.map((e) => _buildTile(e.value).animate().fadeIn(delay: (e.key * 50).ms)),
            const SizedBox(height: 20),
          ],
          if (_yesterday.isNotEmpty) ...[
            _buildSectionHeader('YESTERDAY'),
            ..._yesterday.asMap().entries.map((e) => _buildTile(e.value).animate().fadeIn(delay: (e.key * 50 + 150).ms)),
            const SizedBox(height: 20),
          ],
          if (_earlier.isNotEmpty) ...[
            _buildSectionHeader('EARLIER'),
            ..._earlier.asMap().entries.map((e) => _buildTile(e.value).animate().fadeIn(delay: (e.key * 50 + 300).ms)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTile(VendorNotificationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: item.isUnread ? FontWeight.w800 : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.time,
                    style: TextStyle(
                      color: item.isUnread ? AppColors.accent : AppColors.textSecondaryDark.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: item.isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
