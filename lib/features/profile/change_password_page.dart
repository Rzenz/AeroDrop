import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/supabase_service.dart';

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
  bool _isSaving = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, bool success) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    final currentUser = SupabaseService.client.auth.currentUser;
    final email = currentUser?.email;

    if (email == null || email.isEmpty) {
      _showMessage('No logged in user found.', false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Verify current password first
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // Actually update password in Supabase Auth
      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      _showMessage('Password updated successfully!', true);
      context.pop();
    } on AuthException catch (error) {
      debugPrint('Supabase password update failed: ${error.message}');

      if (!mounted) return;

      String message = 'Password update failed. Please try again.';

      if (error.message.toLowerCase().contains('invalid login credentials')) {
        message = 'Current password is incorrect.';
      } else if (error.message.toLowerCase().contains('weak')) {
        message = 'New password is too weak.';
      }

      _showMessage(message, false);
    } catch (error) {
      debugPrint('Supabase password update failed: $error');

      if (!mounted) return;

      _showMessage('Password update failed. Please try again.', false);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                          colors: [
                            AppColors.accent,
                            AppColors.primary,
                            Colors.transparent,
                          ],
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
                              validator: (val) =>
                                  val == null || val.isEmpty
                                      ? 'Current password is required'
                                      : null,
                            ),
                            const SizedBox(height: 20),
                            CustomTextField(
                              labelText: 'New Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _newPasswordController,
                              obscureText: _obscureText,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'New password is required';
                                }

                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }

                                if (val == _oldPasswordController.text) {
                                  return 'New password must be different';
                                }

                                return null;
                              },
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
                                  data: ThemeData(
                                    unselectedWidgetColor:
                                        AppColors.borderDark,
                                  ),
                                  child: Checkbox(
                                    value: !_obscureText,
                                    onChanged: (val) {
                                      HapticFeedback.lightImpact();
                                      setState(() => _obscureText = !val!);
                                    },
                                    activeColor: AppColors.primaryLight,
                                    checkColor: AppColors.bgDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Show passwords',
                                  style: AppTextStyles.body(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondaryDark,
                                  ),
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
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
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