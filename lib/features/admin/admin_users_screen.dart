import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/services/supabase_service.dart';
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
        final response = await SupabaseService.client
            .from('users')
            .select()
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(response);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _users = [
              {'id': 'usr_mock_1', 'name': 'Canteen Express', 'email': 'canteen@gmail.com', 'role': 'faculty_staff', 'phone_number': '09123456789', 'account_status': 'active'},
              {'id': 'usr_mock_2', 'name': 'UCLM Café Brews', 'email': 'brews@gmail.com', 'role': 'faculty_staff', 'phone_number': '09123456788', 'account_status': 'active'},
              {'id': 'usr_mock_5', 'name': 'Sweet Escape Delights', 'email': 'sweetescape@gmail.com', 'role': 'faculty_staff', 'phone_number': '09171112222', 'account_status': 'pending_approval'},
              {'id': 'usr_mock_6', 'name': 'Quick Byte Canteen', 'email': 'quickbyte@gmail.com', 'role': 'faculty_staff', 'phone_number': '09172223333', 'account_status': 'pending_approval'},
              {'id': 'usr_mock_3', 'name': 'Sarah Jenkins', 'email': 's.jenkins@gmail.com', 'role': 'admin', 'phone_number': '09123456787', 'account_status': 'active'},
              {'id': 'usr_mock_4', 'name': 'John Doe', 'email': 'john.doe@gmail.com', 'role': 'student', 'phone_number': '09123456786', 'account_status': 'suspended'},
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

  Future<void> _handleApproveStore(String userId, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 28),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                final idx = _users.indexWhere((u) => u['id'] == userId);
                if (idx != -1) {
                  _users[idx] = {..._users[idx], 'account_status': 'active'};
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Vendor "$name" is now an Approved Partner!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Approve Application', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSuspend(String userId, String name) async {
    final reasonController = TextEditingController(text: 'Suspended by admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Suspend $name?', style: const TextStyle(color: Colors.white)),
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
            child: const Text('Suspend', style: TextStyle(color: AppColors.danger)),
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
        title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(authProvider).user;

    final filteredUsers = _users.where((user) {
      // 1. Status Filter
      final status = (user['account_status']?.toString() ?? 'active').toLowerCase();
      if (_selectedFilter != 'All') {
        if (_selectedFilter.toLowerCase() != status) {
          return false;
        }
      }

      // 2. Search Query
      final name = (user['name']?.toString() ?? '').toLowerCase();
      final email = (user['email']?.toString() ?? '').toLowerCase();
      final roleStr = (user['role']?.toString() ?? '').toLowerCase();
      final roleLabel = roleStr == 'admin' ? 'admin' : (roleStr == 'faculty_staff' ? 'vendor' : 'user');
      final phone = (user['phone_number']?.toString() ?? '').toLowerCase();
      
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          roleStr.contains(query) ||
          roleLabel.contains(query) ||
          phone.contains(query) ||
          status.contains(query);
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
                  hintText: 'Search by name, email, phone, role...',
                  prefixIcon: Icons.search_rounded,
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ).animate().fadeIn().slideY(begin: 0.1),
                const SizedBox(height: 12),
                
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['All', 'Active', 'Suspended', 'Deleted'].map((filter) {
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
                            color: isSelected ? AppColors.bgDark : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : AppColors.borderDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchUsers,
              color: AppColors.accent,
              backgroundColor: AppColors.cardDark,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : filteredUsers.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Text(
                                  'No matching users found.',
                                  style: TextStyle(color: AppColors.textSecondaryDark),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final name = user['name']?.toString() ?? '';
                            final email = user['email']?.toString() ?? '';
                            final role = user['role']?.toString().toLowerCase() ?? '';
                            final initials = name.isNotEmpty
                                ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                : 'U';
                            final isAdmin = role == 'admin';
                            final status = (user['account_status']?.toString() ?? 'active').toLowerCase();

                            final isCurrentUser = currentUser?.id == user['id'];
                            final canManage = !isCurrentUser && !isAdmin;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderDark),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: isAdmin 
                                            ? AppColors.primaryGradient 
                                            : AppColors.cyanGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: AppTextStyles.title(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          style: AppTextStyles.body(
                                            fontSize: 12,
                                            color: AppColors.textSecondaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Phone: ${user['phone_number'] ?? 'Not provided'}',
                                          style: AppTextStyles.body(
                                            fontSize: 11,
                                            color: AppColors.textSecondaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        // Role Chip
                                        Builder(
                                          builder: (context) {
                                            final isFaculty = role == 'faculty_staff';
                                            final chipColor = isAdmin 
                                                ? AppColors.success 
                                                : (isFaculty ? AppColors.accent : AppColors.primaryLight);
                                            final label = isAdmin 
                                                ? 'ADMIN' 
                                                : (isFaculty ? 'VENDOR' : 'USER');

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: chipColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: chipColor.withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: chipColor,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        // Status Chip
                                        Builder(
                                          builder: (context) {
                                            final statusColor = status == 'active' 
                                                ? AppColors.success 
                                                : (status == 'suspended' 
                                                    ? AppColors.warning 
                                                    : (status == 'pending_approval' 
                                                        ? const Color(0xFFFFD54F) 
                                                        : AppColors.danger));
                                            final displayStatus = status == 'pending_approval' 
                                                ? 'PENDING APPROVAL' 
                                                : status.toUpperCase();

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                displayStatus,
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () => GoRouter.of(context).push('/admin/users/details?email=$email'),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                                      ),
                                                      alignment: Alignment.center,
                                                      child: const Text(
                                                        'View Details',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (canManage && status != 'deleted') ...[
                                                  const SizedBox(width: 8),
                                                  if (status == 'pending_approval')
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () => _handleApproveStore(user['id'], name),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.success.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: AppColors.success),
                                                          ),
                                                          alignment: Alignment.center,
                                                          child: const Text(
                                                            'Approve Store',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.success,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () => status == 'active' 
                                                            ? _confirmSuspend(user['id'], name) 
                                                            : _handleActivate(user['id']),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          decoration: BoxDecoration(
                                                            color: (status == 'active' ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(
                                                              color: (status == 'active' ? AppColors.warning : AppColors.success).withValues(alpha: 0.25),
                                                            ),
                                                          ),
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            status == 'active' ? 'Suspend' : 'Activate',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: status == 'active' ? AppColors.warning : AppColors.success,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => _confirmDelete(user['id'], name),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.danger.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.danger,
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
                                    ],
                                  ),
                                ),
                              ),
                            ).animate(delay: Duration(milliseconds: index * 60))
                             .fadeIn()
                             .slideY(begin: 0.08, end: 0);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}