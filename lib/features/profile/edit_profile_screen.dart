import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authProvider.notifier)
          .updateProfile(_nameController.text, _emailController.text);

      if (!mounted) return;

      final errorMessage = ref.read(authProvider).errorMessage;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile updated successfully!'
                : errorMessage ?? 'Profile update failed.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: const CustomAppBar(title: 'Edit Profile'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F243A), AppColors.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Avatar Edit Circle
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : 'U',
                              style: AppTextStyles.display(fontSize: 36),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => HapticFeedback.lightImpact(),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.bgDark,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),

                  const SizedBox(height: 40),

                  // Fields inside GlassCard
                  GlassCard(
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
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          prefixIcon: Icons.person_outline_rounded,
                          controller: _nameController,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter name' : null,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          labelText: 'Email Address',
                          hintText: 'yourname@email.com',
                          prefixIcon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: true,
                          suffixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.textSecondaryDark,
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 32),
                        GradientButton(
                          text: 'Save Changes',
                          onPressed: _handleSave,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
