import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/location_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/auth_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Active', 'Suspended', 'Deleted'
  String _selectedVendorFilter =
      'Pending'; // 'Pending', 'Approved', 'Rejected', 'Suspended'
  int _currentTab = 0; // 0: Users, 1: Vendor Applications
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    if (_users.isNotEmpty && !SupabaseService.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    try {
      if (SupabaseService.isConfigured) {
        final usersRes = await SupabaseService.client.from('users').select('*');

        final List<Map<String, dynamic>> loadedUsers = [];
        for (final u in usersRes) {
          final userId = u['id'].toString();
          loadedUsers.add({
            'id': userId,
            'email': u['email']?.toString() ?? '',
            'name':
                u['full_name']?.toString() ??
                u['email']?.toString().split('@').first ??
                'User',
            'role': u['role']?.toString() ?? 'user',
            'phone_number': u['phone_number']?.toString() ?? '',
            'account_status': u['account_status']?.toString() ?? 'active',
            'vendor_status': u['vendor_status']?.toString(),
            'business_name': u['business_name']?.toString(),
            'business_description': u['business_description']?.toString() ?? '',
            'campus_location_id': u['campus_location_id']?.toString() ?? '',
            'avatar_url': u['avatar_url']?.toString(),
          });
        }

        if (mounted) {
          setState(() {
            _users = loadedUsers;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _users = [
              {
                'id': 'usr_mock_1',
                'name': 'Canteen Express',
                'email': 'canteen@gmail.com',
                'role': 'vendor',
                'phone_number': '09123456789',
                'account_status': 'active',
              },
              {
                'id': 'usr_mock_2',
                'name': 'UCLM Café Brews',
                'email': 'brews@gmail.com',
                'role': 'vendor',
                'phone_number': '09123456788',
                'account_status': 'active',
              },
              {
                'id': 'usr_mock_5',
                'name': 'Sweet Escape Delights',
                'email': 'sweetescape@gmail.com',
                'role': 'user',
                'vendor_status': 'pending',
                'phone_number': '09171112222',
                'account_status': 'active',
              },
              {
                'id': 'usr_mock_6',
                'name': 'Quick Byte Canteen',
                'email': 'quickbyte@gmail.com',
                'role': 'user',
                'vendor_status': 'pending',
                'phone_number': '09172223333',
                'account_status': 'active',
              },
              {
                'id': 'usr_mock_3',
                'name': 'Sarah Jenkins',
                'email': 's.jenkins@gmail.com',
                'role': 'admin',
                'phone_number': '09123456787',
                'account_status': 'active',
              },
              {
                'id': 'usr_mock_4',
                'name': 'John Doe',
                'email': 'john.doe@gmail.com',
                'role': 'user',
                'phone_number': '09123456786',
                'account_status': 'suspended',
              },
            ];
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Maps any role string to a clean uppercase display label.
  String _roleLabel(String role) {
    switch (role) {
      case 'vendor':
        return 'VENDOR';
      case 'admin':
        return 'ADMIN';
      case 'user':
        return 'USER';
      default:
        // Normalise legacy values that should no longer exist in DB
        return 'USER';
    }
  }

  Future<void> _handleApproveStore(String userId, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Approve Store', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Do you want to approve the vendor application for "$name"? They will immediately be authorized to list products on the platform.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!SupabaseService.isConfigured) {
                setState(() {
                  final idx = _users.indexWhere((u) => u['id'] == userId);
                  if (idx != -1) {
                    _users[idx] = {
                      ..._users[idx],
                      'account_status': 'active',
                      'role': 'vendor',
                    };
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Vendor "$name" is now an Approved Partner!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                return;
              }
              try {
                // 1. Fetch user record first to verify actual details exist
                final userRecord = await SupabaseService.client
                    .from('users')
                    .select()
                    .eq('id', userId)
                    .maybeSingle();

                if (userRecord == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Approval Blocked: User has no application profile record.',
                      ),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                final bizName = userRecord['business_name']?.toString() ?? '';
                final locationId =
                    userRecord['campus_location_id']?.toString() ?? '';

                final List<String> missingFields = [];
                if (bizName.trim().isEmpty) {
                  missingFields.add('Business Name');
                }
                if (locationId.trim().isEmpty) {
                  missingFields.add('Campus Location');
                }

                if (missingFields.isNotEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Approval Blocked: Required fields missing: ${missingFields.join(", ")}',
                      ),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                // 2. Update user to active vendor role
                await SupabaseService.client
                    .from('users')
                    .update({
                      'role': 'vendor',
                      'vendor_status': 'active',
                      'account_status': 'active',
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    })
                    .eq('id', userId);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Vendor "$bizName" has been approved successfully!',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchUsers();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to approve vendor: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text(
              'Approve Application',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRejectStore(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('Reject Application', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to reject the vendor application for "$name"?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await SupabaseService.client
            .from('users')
            .update({
              'vendor_status': 'rejected',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor application for "$name" has been rejected.'),
            backgroundColor: AppColors.danger,
          ),
        );
        _fetchUsers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject vendor: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleSuspendStore(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Suspend Vendor', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to suspend the vendor "$name"? They will no longer be able to receive orders.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Suspend',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await SupabaseService.client
            .from('users')
            .update({
              'vendor_status': 'suspended',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor "$name" has been suspended.'),
            backgroundColor: AppColors.warning,
          ),
        );
        _fetchUsers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to suspend vendor: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmSuspend(String userId, String name) async {
    final reasonController = TextEditingController(text: 'Suspended by admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Suspend $name?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to suspend this account? The user will be blocked from logging in.',
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
            child: const Text(
              'Suspend',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (!SupabaseService.isConfigured) {
        setState(() {
          final idx = _users.indexWhere((u) => u['id'] == userId);
          if (idx != -1) {
            _users[idx] = {..._users[idx], 'account_status': 'suspended'};
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account suspended.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }

      final error = await ref
          .read(authProvider.notifier)
          .suspendUser(userId, reason: reasonController.text);
      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account suspended.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchUsers();
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
    if (!SupabaseService.isConfigured) {
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == userId);
        if (idx != -1) {
          _users[idx] = {..._users[idx], 'account_status': 'active'};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User account activated.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }

    final error = await ref.read(authProvider.notifier).activateUser(userId);
    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User account activated.'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate user: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(String userId, String name) async {
    final reasonController = TextEditingController(text: 'Deleted by admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $name?',
          style: const TextStyle(color: Colors.white),
        ),
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
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (!SupabaseService.isConfigured) {
        setState(() {
          final idx = _users.indexWhere((u) => u['id'] == userId);
          if (idx != -1) {
            _users[idx] = {..._users[idx], 'account_status': 'deleted'};
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account marked as deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }

      final error = await ref
          .read(authProvider.notifier)
          .deleteUserAccount(userId, reason: reasonController.text);
      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchUsers();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(authProvider).user;
    final campusLocations = ref.watch(campusLocationsProvider).value ?? [];

    final filteredUsers = _users.where((user) {
      // 1. Status Filter
      final status = (user['account_status']?.toString() ?? 'active')
          .toLowerCase();
      if (_selectedFilter != 'All') {
        if (_selectedFilter.toLowerCase() != status) {
          return false;
        }
      }

      // 2. Search Query
      final name = (user['name']?.toString() ?? '').toLowerCase();
      final email = (user['email']?.toString() ?? '').toLowerCase();
      final roleStr = (user['role']?.toString() ?? '').toLowerCase();
      final roleLabel = roleStr == 'admin'
          ? 'admin'
          : (roleStr == 'vendor' ? 'vendor' : 'user');
      final phone = (user['phone_number']?.toString() ?? '').toLowerCase();

      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          roleStr.contains(query) ||
          roleLabel.contains(query) ||
          phone.contains(query) ||
          status.contains(query);
    }).toList();

    final filteredVendors = _users.where((user) {
      final vStatus = user['vendor_status']?.toString();
      if (vStatus == null) return false;

      final targetStatus = _selectedVendorFilter == 'Approved'
          ? 'active'
          : _selectedVendorFilter.toLowerCase();

      if (vStatus != targetStatus) return false;

      final name = (user['name']?.toString() ?? '').toLowerCase();
      final bizName = (user['business_name']?.toString() ?? '').toLowerCase();
      final email = (user['email']?.toString() ?? '').toLowerCase();
      final phone = (user['phone_number']?.toString() ?? '').toLowerCase();

      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          bizName.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // Header & Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy & Operator Directory',
                  style: AppTextStyles.title(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Manage campus delivery roles and access standing',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: '',
                  hintText: _currentTab == 0
                      ? 'Search by name, email, phone, role...'
                      : 'Search by store name, owner name, email, phone...',
                  prefixIcon: Icons.search_rounded,
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ).animate().fadeIn().slideY(begin: 0.1),
              ],
            ),
          ),

          // Custom Tabs Toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentTab = 0;
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _currentTab == 0
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'User Directory',
                          style: TextStyle(
                            color: _currentTab == 0
                                ? AppColors.bgDark
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentTab = 1;
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _currentTab == 1
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Vendor Applications',
                          style: TextStyle(
                            color: _currentTab == 1
                                ? AppColors.bgDark
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sub-filters and List Content
          Expanded(
            child: _currentTab == 0
                ? Column(
                    children: [
                      // Filter chips for Users
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: ['All', 'Active', 'Suspended', 'Deleted']
                                .map((filter) {
                                  final isSelected = _selectedFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(filter),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedFilter = filter;
                                          });
                                        }
                                      },
                                      backgroundColor: AppColors.cardDark,
                                      selectedColor: AppColors.accent,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? AppColors.bgDark
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.transparent
                                              : AppColors.borderDark,
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                      // Users List View
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchUsers,
                          color: AppColors.accent,
                          backgroundColor: AppColors.cardDark,
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                )
                              : filteredUsers.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.4,
                                      child: Center(
                                        child: Text(
                                          'No users found.',
                                          style: TextStyle(
                                            color: AppColors.textSecondaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    80,
                                  ),
                                  itemCount: filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = filteredUsers[index];
                                    final name = user['name']?.toString() ?? '';
                                    final email =
                                        user['email']?.toString() ?? '';
                                    final role =
                                        user['role']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    final initials = name.isNotEmpty
                                        ? name
                                              .split(' ')
                                              .map((e) => e[0])
                                              .take(2)
                                              .join()
                                              .toUpperCase()
                                        : 'U';
                                    final isAdmin = role == 'admin';
                                    final status =
                                        (user['account_status']?.toString() ??
                                                'active')
                                            .toLowerCase();
                                    final isCurrentUser =
                                        currentUser?.id == user['id'];
                                    final canManage =
                                        !isCurrentUser && !isAdmin;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: AppColors
                                                      .accent
                                                      .withValues(alpha: 0.1),
                                                  backgroundImage:
                                                      user['avatar_url'] != null
                                                      ? NetworkImage(
                                                          user['avatar_url'],
                                                        )
                                                      : null,
                                                  child:
                                                      user['avatar_url'] == null
                                                      ? Text(
                                                          initials,
                                                          style:
                                                              const TextStyle(
                                                                color: AppColors
                                                                    .accent,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            name,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14.5,
                                                                ),
                                                          ),
                                                          if (isCurrentUser) ...[
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: AppColors
                                                                    .accent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              child: const Text(
                                                                'You',
                                                                style: TextStyle(
                                                                  color: AppColors
                                                                      .accent,
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        email,
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .textSecondaryDark,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _roleLabel(role),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      status.toUpperCase(),
                                                      style: TextStyle(
                                                        color:
                                                            status == 'active'
                                                            ? AppColors.success
                                                            : (status ==
                                                                      'suspended'
                                                                  ? AppColors
                                                                        .warning
                                                                  : AppColors
                                                                        .danger),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      context.push(
                                                        '/admin/users/${user['id']}',
                                                      );
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: AppColors
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                        ),
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Text(
                                                        'View Details',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (canManage &&
                                                    status != 'deleted') ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () =>
                                                          status == 'active'
                                                          ? _confirmSuspend(
                                                              user['id'],
                                                              name,
                                                            )
                                                          : _handleActivate(
                                                              user['id'],
                                                            ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              (status ==
                                                                          'active'
                                                                      ? AppColors
                                                                            .warning
                                                                      : AppColors
                                                                            .success)
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                (status ==
                                                                            'active'
                                                                        ? AppColors
                                                                              .warning
                                                                        : AppColors
                                                                              .success)
                                                                    .withValues(
                                                                      alpha:
                                                                          0.25,
                                                                    ),
                                                          ),
                                                        ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          status == 'active'
                                                              ? 'Suspend'
                                                              : 'Activate',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                status ==
                                                                    'active'
                                                                ? AppColors
                                                                      .warning
                                                                : AppColors
                                                                      .success,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () =>
                                                          _confirmDelete(
                                                            user['id'],
                                                            name,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .danger
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: AppColors
                                                                .danger
                                                                .withValues(
                                                                  alpha: 0.25,
                                                                ),
                                                          ),
                                                        ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .danger,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideY(begin: 0.08, end: 0);
                                  },
                                ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Filter chips for Vendor Applications
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children:
                                [
                                  'Pending',
                                  'Approved',
                                  'Rejected',
                                  'Suspended',
                                ].map((filter) {
                                  final isSelected =
                                      _selectedVendorFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(filter),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedVendorFilter = filter;
                                          });
                                        }
                                      },
                                      backgroundColor: AppColors.cardDark,
                                      selectedColor: AppColors.accent,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? AppColors.bgDark
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.transparent
                                              : AppColors.borderDark,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                      // Vendor Applications list
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchUsers,
                          color: AppColors.accent,
                          backgroundColor: AppColors.cardDark,
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                )
                              : filteredVendors.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.4,
                                      child: Center(
                                        child: Text(
                                          'No vendor applications found.',
                                          style: TextStyle(
                                            color: AppColors.textSecondaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    80,
                                  ),
                                  itemCount: filteredVendors.length,
                                  itemBuilder: (context, index) {
                                    final vendor = filteredVendors[index];
                                    final name =
                                        vendor['name']?.toString() ?? '';
                                    final bizName =
                                        vendor['business_name']?.toString() ??
                                        'Store Name';
                                    final bizDesc =
                                        vendor['business_description']
                                            ?.toString() ??
                                        'No description provided.';
                                    final email =
                                        vendor['email']?.toString() ?? '';
                                    final phone =
                                        vendor['phone_number']?.toString() ??
                                        '';
                                    final vStatus =
                                        (vendor['vendor_status']?.toString() ??
                                                'pending')
                                            .toLowerCase();

                                    // Resolve campus location name
                                    final locationId =
                                        vendor['campus_location_id']
                                            ?.toString() ??
                                        '';
                                    final loc = campusLocations.firstWhere(
                                      (l) => l.id == locationId,
                                      orElse: () => CampusLocation(
                                        id: '',
                                        name: 'Unknown Location',
                                        locationCode: 'UNK',
                                        latitude: 0,
                                        longitude: 0,
                                        isActive: true,
                                      ),
                                    );
                                    final locationName = loc.name;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: AppColors
                                                      .accent
                                                      .withValues(alpha: 0.1),
                                                  backgroundImage:
                                                      vendor['avatar_url'] !=
                                                          null
                                                      ? NetworkImage(
                                                          vendor['avatar_url'],
                                                        )
                                                      : null,
                                                  child:
                                                      vendor['avatar_url'] ==
                                                          null
                                                      ? const Icon(
                                                          Icons
                                                              .storefront_rounded,
                                                          color:
                                                              AppColors.accent,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        bizName,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Owner: $name',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: vStatus == 'active'
                                                        ? AppColors.success
                                                              .withValues(
                                                                alpha: 0.15,
                                                              )
                                                        : (vStatus == 'pending'
                                                              ? AppColors.accent
                                                                    .withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    )
                                                              : AppColors.danger
                                                                    .withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    )),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: vStatus == 'active'
                                                          ? AppColors.success
                                                          : (vStatus ==
                                                                    'pending'
                                                                ? AppColors
                                                                      .accent
                                                                : AppColors
                                                                      .danger),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    vStatus.toUpperCase(),
                                                    style: TextStyle(
                                                      color: vStatus == 'active'
                                                          ? AppColors.success
                                                          : (vStatus ==
                                                                    'pending'
                                                                ? AppColors
                                                                      .accent
                                                                : AppColors
                                                                      .danger),
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(
                                              color: Colors.white10,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildInfoRow(
                                              Icons.email_outlined,
                                              email,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.phone_outlined,
                                              phone,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.pin_drop_outlined,
                                              locationName,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Description:',
                                              style: TextStyle(
                                                color:
                                                    AppColors.textSecondaryDark,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              bizDesc,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      context.push(
                                                        '/admin/users/${vendor['id']}',
                                                      );
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: AppColors
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                        ),
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Text(
                                                        'View Details',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (vStatus == 'pending') ...[
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.check,
                                                        size: 16,
                                                        color: AppColors.bgDark,
                                                      ),
                                                      label: const Text(
                                                        'Approve',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.success,
                                                        foregroundColor:
                                                            AppColors.bgDark,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _handleApproveStore(
                                                            vendor['id'],
                                                            bizName,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        size: 16,
                                                        color: AppColors.danger,
                                                      ),
                                                      label: const Text(
                                                        'Reject',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        side: const BorderSide(
                                                          color:
                                                              AppColors.danger,
                                                        ),
                                                        foregroundColor:
                                                            AppColors.danger,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _handleRejectStore(
                                                            vendor['id'],
                                                            bizName,
                                                          ),
                                                    ),
                                                  ),
                                                ] else if (vStatus ==
                                                    'active') ...[
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      icon: const Icon(
                                                        Icons.block,
                                                        size: 16,
                                                        color:
                                                            AppColors.warning,
                                                      ),
                                                      label: const Text(
                                                        'Suspend',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        side: const BorderSide(
                                                          color:
                                                              AppColors.warning,
                                                        ),
                                                        foregroundColor:
                                                            AppColors.warning,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _handleSuspendStore(
                                                            vendor['id'],
                                                            bizName,
                                                          ),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.refresh,
                                                        size: 16,
                                                        color: AppColors.bgDark,
                                                      ),
                                                      label: const Text(
                                                        'Re-Activate / Approve',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.accent,
                                                        foregroundColor:
                                                            AppColors.bgDark,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _handleApproveStore(
                                                            vendor['id'],
                                                            bizName,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideY(begin: 0.08, end: 0);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
