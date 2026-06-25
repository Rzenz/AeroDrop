import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_text_field.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _allUsers = [
    {'name': 'Professor Green', 'email': 'p.green@uclm.edu', 'role': 'User (Faculty)', 'dept': 'Science Department'},
    {'name': 'Dean Harrison', 'email': 'd.harrison@uclm.edu', 'role': 'User (Faculty)', 'dept': 'Engineering Department'},
    {'name': 'Sarah Jenkins', 'email': 's.jenkins@uclm.edu', 'role': 'Admin (Fleet Commander)', 'dept': 'Logistics & Fleet control'},
    {'name': 'John Doe', 'email': 'john.doe@uclm.edu', 'role': 'User (Student)', 'dept': 'Computer Studies Council'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _allUsers.where((user) {
      final name = user['name']!.toLowerCase();
      final email = user['email']!.toLowerCase();
      final dept = user['dept']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query) || dept.contains(query);
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
                  'Users & Operators',
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
            child: filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No matching users found.',
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final name = user['name']!;
                      final initials = name.isNotEmpty
                          ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                          : 'U';
                      final isAdmin = user['role']!.contains('Admin');

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
                                user['email']!,
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (isAdmin ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isAdmin ? AppColors.success : AppColors.primary).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  isAdmin ? 'ADMIN' : 'MEMBER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? AppColors.success : AppColors.primary,
                                  ),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.business_center_outlined, size: 16, color: AppColors.secondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Department: ${user['dept']!}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondaryDark,
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
        ],
      ),
    );
  }
}
