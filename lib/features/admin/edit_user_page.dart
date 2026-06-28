import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';

class EditUserPage extends ConsumerStatefulWidget {
  final String email;
  const EditUserPage({super.key, required this.email});

  @override
  ConsumerState<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends ConsumerState<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _deptController;
  String _selectedRole = 'User (Student)';
  String _selectedStatus = 'Active';

  @override
  void initState() {
    super.initState();
    // ponytail: mocked initial user prefill logic
    final name = widget.email.split('@').first.replaceAll('.', ' ');
    final displayName = name.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
    final isFaculty = widget.email.contains('.edu') && !widget.email.contains('student');

    _nameController = TextEditingController(text: displayName);
    _deptController = TextEditingController(
      text: isFaculty ? 'Engineering & Technology' : 'Computer Studies Council',
    );
    _selectedRole = isFaculty ? 'User (Faculty)' : 'User (Student)';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User access updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradientDark),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
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
                        'Edit Account Access',
                        style: AppTextStyles.title(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 36),

                  // Fields
                  Expanded(
                    child: SingleChildScrollView(
                      child: GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomTextField(
                              labelText: 'Full Name',
                              hintText: 'John Doe',
                              controller: _nameController,
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Department / Council',
                              hintText: 'e.g. Engineering Department',
                              controller: _deptController,
                              prefixIcon: Icons.business_center_outlined,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            _buildDropdownField(
                              labelText: 'System Access Role',
                              value: _selectedRole,
                              items: const ['User (Student)', 'User (Faculty)', 'Admin (Fleet Commander)'],
                              onChanged: (val) => setState(() => _selectedRole = val!),
                            ),
                            const SizedBox(height: 20),
                            _buildDropdownField(
                              labelText: 'Account Standing',
                              value: _selectedStatus,
                              items: const ['Active', 'Suspended'],
                              onChanged: (val) => setState(() => _selectedStatus = val!),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                  ),

                  // Save Button
                  CustomButton(
                    text: 'Save Modifications',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _save,
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String labelText,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.cardDark,
              items: items.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 14)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
