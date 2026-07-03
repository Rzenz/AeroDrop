import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/auth_provider.dart';

class UserDetailsPage extends ConsumerStatefulWidget {
  final String email;
  const UserDetailsPage({super.key, required this.email});

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage> {
  Map<String, dynamic>? _userProfile;
  bool _loading = true;
  String? _errorMessage;
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _activeFlights = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndStats();
  }

  Future<void> _loadUserAndStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (SupabaseService.isConfigured) {
        final userResponse = await SupabaseService.client
            .from('users')
            .select()
            .eq('email', widget.email)
            .maybeSingle();

        if (userResponse != null) {
          final userId = userResponse['id']?.toString() ?? '';

          final ordersResponse = await SupabaseService.client
              .from('deliveries')
              .select('status')
              .eq('user_id', userId);

          final ordersList = ordersResponse as List;
          final total = ordersList.length;
          final completed = ordersList.where((o) => o['status']?.toString() == 'delivered').length;
          final active = ordersList.where((o) => o['status']?.toString() == 'inTransit' || o['status']?.toString() == 'in_transit').length;

          if (mounted) {
            setState(() {
              _userProfile = Map<String, dynamic>.from(userResponse);
              _totalOrders = total;
              _completedOrders = completed;
              _activeFlights = active;
              _loading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'User not found in operator directory.';
              _loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _userProfile = {
              'id': 'usr_mock',
              'name': widget.email.split('@').first.replaceAll('.', ' '),
              'email': widget.email,
              'role': widget.email.contains('.edu') ? 'faculty_staff' : 'student',
              'phone_number': '+63 912 345 6789',
              'account_status': 'active',
            };
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmSuspend(String userId) async {
    final reasonController = TextEditingController(text: 'Suspended by admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Suspend User Account?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to suspend this account? The user will be signed out and blocked from logging in.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              labelText: 'Suspension Reason',
              hintText: 'e.g. Policy violation',
              controller: reasonController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Suspend', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final error = await ref.read(authProvider.notifier).suspendUser(
            userId,
            reason: reasonController.text,
          );
      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account suspended.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadUserAndStats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to suspend user: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleActivate(String userId) async {
    final error = await ref.read(authProvider.notifier).activateUser(userId);
    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User account activated.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadUserAndStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate user: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(String userId) async {
    final reasonController = TextEditingController(text: 'Deleted by admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User Account?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark the account as deleted and prevent the user from logging in. Delivery records will remain for history and accountability.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              labelText: 'Delete Reason',
              hintText: 'e.g. Account closure request',
              controller: reasonController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final error = await ref.read(authProvider.notifier).deleteUserAccount(
            userId,
            reason: reasonController.text,
          );
      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadUserAndStats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Back',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userId = _userProfile?['id']?.toString() ?? '';
    final name = _userProfile?['name']?.toString() ?? '';
    final email = _userProfile?['email']?.toString() ?? widget.email;
    final rawRole = _userProfile?['role']?.toString().toLowerCase() ?? '';
    final role = rawRole == 'admin'
        ? 'Admin'
        : (rawRole == 'faculty_staff' ? 'Faculty/Staff' : 'Student');
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';
    final phoneNumVal = _userProfile?['phone_number']?.toString() ?? '';
    final contactNumber = phoneNumVal.trim().isEmpty ? 'Not Provided' : phoneNumVal;
    final status = _userProfile?['account_status']?.toString().toLowerCase() ?? 'active';

    final createdAtVal = _userProfile?['created_at'];
    String joinedDate = 'Not Available';
    if (createdAtVal != null) {
      try {
        final dt = DateTime.parse(createdAtVal.toString());
        joinedDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final currentUser = ref.read(authProvider).user;
    final isCurrentUser = currentUser?.id == _userProfile?['id'];
    final isTargetAdmin = rawRole == 'admin';
    final canManage = !isCurrentUser && !isTargetAdmin;

    Color statusColor = AppColors.success;
    if (status == 'suspended') {
      statusColor = AppColors.warning;
    } else if (status == 'deleted') {
      statusColor = AppColors.danger;
    }

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
                    Text(
                      'User Profile Details',
                      style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 32),

                // Main Info
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Avatar & Name Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.cyanGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                name,
                                style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: AppTextStyles.body(fontSize: 13, color: AppColors.textSecondaryDark),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  StatusChip(
                                    label: status.toUpperCase(),
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: role.toUpperCase(),
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Details Card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Personal Information',
                                style: AppTextStyles.title(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(Icons.person_outline_rounded, 'Full Name', name),
                              _buildDivider(),
                              _buildDetailRow(Icons.email_outlined, 'Email Address', email),
                              _buildDivider(),
                              _buildDetailRow(Icons.phone_outlined, 'Contact Number', contactNumber),
                              _buildDivider(),
                              _buildDetailRow(Icons.badge_outlined, 'Access Role', role),
                              _buildDivider(),
                              _buildDetailRow(Icons.info_outline, 'Status', status.toUpperCase()),
                              _buildDivider(),
                              _buildDetailRow(Icons.calendar_today_outlined, 'Joined Date', joinedDate),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                        const SizedBox(height: 20),

                        // Stats Card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat('$_totalOrders', 'Total Orders'),
                              _buildVerticalDivider(),
                              _buildStat('$_completedOrders', 'Completed'),
                              _buildVerticalDivider(),
                              _buildStat('$_activeFlights', 'Active Flight'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!canManage) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Administrative accounts cannot be suspended or deleted.',
                            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ] else if (status == 'deleted') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block_flipped, color: AppColors.danger, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ACCOUNT STATUS: DELETED',
                              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (status == 'active') ...[
                        CustomButton(
                          text: 'Suspend Account',
                          icon: Icons.pause_circle_outline_rounded,
                          gradient: const LinearGradient(colors: [Color(0xFFD35400), Color(0xFFE67E22)]),
                          onPressed: () => _confirmSuspend(userId),
                        ),
                        const SizedBox(height: 12),
                      ] else if (status == 'suspended') ...[
                        CustomButton(
                          text: 'Activate Account',
                          icon: Icons.play_circle_outline_rounded,
                          gradient: const LinearGradient(colors: [Color(0xFF27AE60), Color(0xFF2ECC71)]),
                          onPressed: () => _handleActivate(userId),
                        ),
                        const SizedBox(height: 12),
                      ],
                      CustomButton(
                        text: 'Delete User Account',
                        icon: Icons.delete_forever_rounded,
                        gradient: AppColors.dangerGradient,
                        onPressed: () => _confirmDelete(userId),
                      ),
                    ],
                  ],
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.title(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: AppColors.borderDark.withValues(alpha: 0.5), height: 1),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.body(fontSize: 11, color: AppColors.textSecondaryDark)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.borderDark,
    );
  }
}
