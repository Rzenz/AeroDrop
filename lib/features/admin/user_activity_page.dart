import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';

class UserActivityPage extends ConsumerWidget {
  final String email;
  const UserActivityPage({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ponytail: mocked list of user activity audit entries
    final List<Map<String, String>> activities = [
      {
        'title': 'Authenticated Session',
        'desc': 'Successfully signed into AeroDrop web application from Chrome / macOS.',
        'time': 'Just now',
        'icon': 'login_rounded',
        'color': 'success',
      },
      {
        'title': 'Created Dispatch Request #AD-9084',
        'desc': 'Requested urgent payload delivery of "Lab Equipments" to Science Building Platform.',
        'time': '2 hours ago',
        'icon': 'flight_takeoff_rounded',
        'color': 'primary',
      },
      {
        'title': 'Updated Account Profile',
        'desc': 'Modified display name from placeholder to official name directory listing.',
        'time': 'Yesterday at 4:15 PM',
        'icon': 'person_outline_rounded',
        'color': 'secondary',
      },
      {
        'title': 'Settings Updated',
        'desc': 'Activated persistent dark mode preference and push notification controls.',
        'time': 'June 24, 2026, 11:32 AM',
        'icon': 'settings_outlined',
        'color': 'warning',
      },
      {
        'title': 'Password Modification',
        'desc': 'Successfully updated password credentials. Active sessions refreshed.',
        'time': 'June 20, 2026, 9:02 AM',
        'icon': 'lock_outline_rounded',
        'color': 'danger',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Activity Logs',
                            style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            email,
                            style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Activity Logs
                Expanded(
                  child: ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final act = activities[index];
                      final title = act['title']!;
                      final desc = act['desc']!;
                      final time = act['time']!;
                      
                      Color iconColor;
                      IconData iconData;
                      switch (act['icon']) {
                        case 'login_rounded':
                          iconData = Icons.login_rounded;
                          break;
                        case 'flight_takeoff_rounded':
                          iconData = Icons.flight_takeoff_rounded;
                          break;
                        case 'person_outline_rounded':
                          iconData = Icons.person_outline_rounded;
                          break;
                        case 'settings_outlined':
                          iconData = Icons.settings_outlined;
                          break;
                        default:
                          iconData = Icons.lock_outline_rounded;
                      }

                      switch (act['color']) {
                        case 'success':
                          iconColor = AppColors.success;
                          break;
                        case 'primary':
                          iconColor = AppColors.primary;
                          break;
                        case 'secondary':
                          iconColor = AppColors.secondary;
                          break;
                        case 'warning':
                          iconColor = AppColors.warning;
                          break;
                        default:
                          iconColor = AppColors.danger;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline stem indicator
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1),
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 16),
                                ),
                                if (index != activities.length - 1)
                                  Container(
                                    width: 2,
                                    height: 52,
                                    color: AppColors.borderDark,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // Log details
                            Expanded(
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        Text(
                                          time,
                                          style: AppTextStyles.body(fontSize: 10, color: AppColors.textSecondaryDark),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      desc,
                                      style: AppTextStyles.body(fontSize: 12, color: AppColors.textSecondaryDark),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: Duration(milliseconds: index * 80))
                       .fadeIn()
                       .slideY(begin: 0.05);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
