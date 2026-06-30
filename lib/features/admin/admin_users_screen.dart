import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';

import '../../core/services/supabase_service.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
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
              {'name': 'Professor Green', 'email': 'p.green@uclm.edu', 'role': 'faculty_staff', 'dept': 'Science Department'},
              {'name': 'Dean Harrison', 'email': 'd.harrison@uclm.edu', 'role': 'faculty_staff', 'dept': 'Engineering Department'},
              {'name': 'Sarah Jenkins', 'email': 's.jenkins@uclm.edu', 'role': 'admin', 'dept': 'Logistics & Fleet control'},
              {'name': 'John Doe', 'email': 'john.doe@gmail.com', 'role': 'student', 'dept': 'Computer Studies Council'},
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final name = (user['name']?.toString() ?? '').toLowerCase();
      final email = (user['email']?.toString() ?? '').toLowerCase();
      final role = (user['role']?.toString() ?? '').toLowerCase();
      final dept = (user['dept']?.toString() ?? user['department']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || role.contains(query) || dept.contains(query);
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
                  'Manage campus delivery roles and access permissions',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: '',
                  hintText: 'Search by name, email, department...',
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

                            final dept = user['dept']?.toString() ?? 
                                         user['department']?.toString() ?? 
                                         (role == 'faculty_staff' ? 'Engineering & Technology' : 'Computer Studies Council');

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
                                    subtitle: Text(
                                      email,
                                      style: AppTextStyles.body(
                                        fontSize: 12,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    trailing: Builder(
                                      builder: (context) {
                                        final isFaculty = role == 'faculty_staff';
                                        final chipColor = isAdmin 
                                            ? AppColors.success 
                                            : (isFaculty ? AppColors.accent : AppColors.primaryLight);
                                        final label = isAdmin 
                                            ? 'ADMIN' 
                                            : (isFaculty ? 'FACULTY/STAFF' : 'STUDENT');

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: chipColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: chipColor.withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: chipColor,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.business_center_outlined, size: 16, color: AppColors.secondary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Department: $dept',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textSecondaryDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            GestureDetector(
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
                                                  'Manage Account Details',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
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
