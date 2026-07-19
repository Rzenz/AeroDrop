import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';

class AdminUserDetailsScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailsScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  Map<String, dynamic>? _user;
  String? _locationName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!SupabaseService.isConfigured) {
        throw Exception('Supabase is not configured');
      }

      final userRow = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      if (userRow == null) {
        setState(() {
          _user = null;
          _loading = false;
          _error = 'Account not found.';
        });
        return;
      }

      String? locName;
      final locId = userRow['campus_location_id'];
      if (locId != null && locId.toString().isNotEmpty) {
        final locRow = await SupabaseService.client
            .from('campus_locations')
            .select('name')
            .eq('id', locId)
            .maybeSingle();
        if (locRow != null) {
          locName = locRow['name']?.toString();
        }
      }

      setState(() {
        _user = Map<String, dynamic>.from(userRow);
        _locationName = locName;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      setState(() {
        _error = 'Unable to load profile. Please check connection.';
        _loading = false;
      });
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminId = SupabaseService.isConfigured
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    final isSelf = _user != null && _user!['id'] == currentAdminId;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Account Details'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bgDark,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: _user!['avatar_url'] == null
                                    ? AppColors.primaryGradient
                                    : null,
                                color: _user!['avatar_url'] != null
                                    ? AppColors.cardDark
                                    : null,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 3,
                                ),
                                image: _user!['avatar_url'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          _user!['avatar_url']!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _user!['avatar_url'] == null
                                  ? Center(
                                      child: Text(
                                        _user!['full_name'] != null &&
                                                _user!['full_name']
                                                    .toString()
                                                    .isNotEmpty
                                            ? _user!['full_name']
                                                  .toString()[0]
                                                  .toUpperCase()
                                            : 'U',
                                        style: AppTextStyles.display(
                                          fontSize: 36,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ).animate().scale(
                        curve: Curves.elasticOut,
                        duration: 600.ms,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _user!['full_name']?.toString() ?? 'No Name',
                          style: AppTextStyles.subHead(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (_user!['role']?.toString() ?? 'user')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Information',
                              style: AppTextStyles.subHead(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              Icons.email_outlined,
                              'Email Address',
                              _user!['email']?.toString().trim().isEmpty ==
                                      false
                                  ? _user!['email']!.toString().trim()
                                  : 'Not provided',
                            ),
                            _buildDetailRow(
                              Icons.phone_android_rounded,
                              'Phone Number',
                              _user!['phone_number']
                                          ?.toString()
                                          .trim()
                                          .isEmpty ==
                                      false
                                  ? _user!['phone_number']!.toString().trim()
                                  : 'Not provided',
                            ),
                            _buildDetailRow(
                              Icons.info_outline,
                              'Account Status',
                              _user!['account_status'] ?? 'active',
                            ),
                            _buildDetailRow(
                              Icons.calendar_today_outlined,
                              'Member Since',
                              _user!['created_at'] != null
                                  ? DateTime.tryParse(
                                          _user!['created_at'].toString(),
                                        )?.toLocal().toString().split(' ')[0] ??
                                        'Not available'
                                  : 'Not available',
                            ),
                            _buildDetailRow(
                              Icons.edit_calendar_outlined,
                              'Last Updated',
                              _user!['updated_at'] != null
                                  ? DateTime.tryParse(
                                          _user!['updated_at'].toString(),
                                        )?.toLocal().toString().split(' ')[0] ??
                                        'Not available'
                                  : 'Not available',
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms),
                      if (_user!['role'] == 'vendor' ||
                          _user!['vendor_status'] != null) ...[
                        const SizedBox(height: 20),
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vendor Application Information',
                                style: AppTextStyles.subHead(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_user!['business_logo_url'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Center(
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundImage: NetworkImage(
                                        _user!['business_logo_url']!,
                                      ),
                                    ),
                                  ),
                                ),
                              _buildDetailRow(
                                Icons.storefront_rounded,
                                'Business Name',
                                _user!['business_name'] ?? 'Not provided',
                              ),
                              _buildDetailRow(
                                Icons.category_outlined,
                                'Category',
                                _user!['business_category'] ?? 'Not provided',
                              ),
                              _buildDetailRow(
                                Icons.description_outlined,
                                'Description',
                                _user!['business_description'] ??
                                    'Not provided',
                              ),
                              _buildDetailRow(
                                Icons.pin_drop_outlined,
                                'Campus Location',
                                _locationName ?? 'Not provided',
                              ),
                              if (_user!['vendor_status'] != null)
                                _buildDetailRow(
                                  Icons.check_circle_outline,
                                  'Vendor Status',
                                  _user!['vendor_status']!,
                                ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                      if (isSelf && _user!['role'] != 'admin') ...[
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/user/profile/edit');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.bgDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          label: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
