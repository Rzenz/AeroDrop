import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/phone_input_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_feedback.dart';
import '../../core/widgets/neu_text_field.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isPhoneValid => isValidPhoneNumber(_phoneController.text);

  Future<void> _handleSave() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final rawPhone = _phoneController.text.trim();
    String normalizedPhone;
    try {
      normalizedPhone = normalizePhoneNumber(rawPhone);
    } catch (e) {
      setState(() => _submitting = false);
      showNeuSnack(
        context,
        'Please enter a valid Philippine mobile number (e.g. 09171234567 or +639171234567).',
        tone: NeuToneKind.error,
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final hasSession = SupabaseService.isConfigured &&
        SupabaseService.client.auth.currentSession != null;
    if (user == null || !hasSession) {
      setState(() => _submitting = false);
      showNeuSnack(
        context,
        'Session expired or not signed in. Please sign in again.',
        tone: NeuToneKind.error,
      );
      context.go('/welcome');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(
          user.fullName.isNotEmpty ? user.fullName : 'Customer',
          user.email,
          phoneNumber: normalizedPhone,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      showNeuSnack(
        context,
        'Profile completed successfully! Welcome to AeroDrop.',
        tone: NeuToneKind.success,
      );
      final updatedUser = ref.read(authProvider).user;
      if (updatedUser != null) {
        if (updatedUser.isAdmin) {
          context.go('/admin');
        } else if (updatedUser.isVendor) {
          context.go('/vendor');
        } else if (updatedUser.isPendingVendor) {
          context.go('/account-pending');
        } else {
          context.go('/user');
        }
      }
    } else {
      final err =
          ref.read(authProvider).errorMessage ?? 'Failed to update phone number.';
      showNeuSnack(context, err, tone: NeuToneKind.error);
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.lightImpact();
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final gutter = AppSpacing.pageGutter(context);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppSpacing.lg * 2),
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BrandMark(size: 44),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Complete your profile',
                          style: AppTextStyles.display(fontSize: 24),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Add your mobile number so our drone dispatch system can send arrival notifications.',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // User summary card
                        if (user != null) ...[
                          NeuCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                    border: Border.all(
                                      color: AppColors.accent.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: AppColors.accent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName
                                            : 'Google User',
                                        style: AppTextStyles.subHead(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        user.email,
                                        style: AppTextStyles.caption(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        NeuTextField(
                          controller: _phoneController,
                          labelText: 'Mobile number',
                          hintText: '0917 123 4567',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android_rounded,
                          inputFormatters: const [
                            PhoneInputFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your mobile number';
                            }
                            try {
                              normalizePhoneNumber(value);
                              return null;
                            } catch (_) {
                              return 'Please enter a valid format (e.g. 0917 123 4567)';
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Format: 09XX XXX XXXX or +63 9XX XXX XXXX',
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const Spacer(),
                        const SizedBox(height: AppSpacing.xl),

                        NeuButton(
                          text: 'Save and continue',
                          isLoading: _submitting || authState.isLoading,
                          onPressed:
                              _isPhoneValid &&
                                  !_submitting &&
                                  !authState.isLoading
                              ? _handleSave
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton(
                            onPressed: _handleSignOut,
                            child: Text(
                              'Sign out and use another account',
                              style: AppTextStyles.caption(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
