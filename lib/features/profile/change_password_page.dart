import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password updated successfully!'),
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
      appBar: const CustomAppBar(title: 'Change Password'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: GlassCard(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(24),
                        borderGradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.primary, Colors.transparent],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        child: Column(
                          children: [
                            CustomTextField(
                              labelText: 'Current Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _oldPasswordController,
                              obscureText: _obscureText,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'New Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _newPasswordController,
                              obscureText: _obscureText,
                              validator: (val) => val == null || val.length < 6 ? 'Password must be >= 6 characters' : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'Confirm New Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _confirmPasswordController,
                              obscureText: _obscureText,
                              validator: (val) {
                                if (val != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Theme(
                                  data: ThemeData(unselectedWidgetColor: AppColors.borderDark),
                                  child: Checkbox(
                                    value: !_obscureText,
                                    onChanged: (val) {
                                      HapticFeedback.lightImpact();
                                      setState(() => _obscureText = !val!);
                                    },
                                    activeColor: AppColors.primaryLight,
                                    checkColor: AppColors.bgDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                Text(
                                  'Show passwords',
                                  style: AppTextStyles.body(fontSize: 13.5, color: AppColors.textSecondaryDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: GradientButton(
                      text: 'Save Password',
                      onPressed: _save,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
