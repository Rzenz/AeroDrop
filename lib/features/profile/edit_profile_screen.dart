import 'package:flutter/material.dart';
import '../../core/widgets/neu_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_button.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/vendor_provider.dart';
import '../../core/utils/image_utils.dart';
import '../auth/presentation/controllers/register_controller.dart';
import '../../core/constants/vendor_categories.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescController;
  late TextEditingController _customCategoryController;
  String? _selectedCategory;
  String? _selectedLocationId;
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    try {
      final XFile? image = await ImageUtils.pickAndCropImage(
        source: ImageSource.gallery,
        title: 'Crop Profile Avatar',
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          if (!mounted) return;
          showNeuSnack(
            context,
            'Avatar file size must be less than 2MB',
            tone: NeuToneKind.error,
          );
          return;
        }

        setState(() => _uploadingAvatar = true);
        final success = await ref
            .read(authProvider.notifier)
            .updateAvatar(image);
        setState(() => _uploadingAvatar = false);

        if (mounted) {
          showNeuSnack(
            context,
            success
                ? 'Profile picture updated!'
                : 'Failed to upload profile picture.',
            tone: NeuToneKind.success,
          );
        }
      }
    } catch (e) {
      debugPrint('Error changing avatar: $e');
      setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.base,
        title: Text(
          'Remove Avatar',
          style: AppTextStyles.body(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove your profile picture?',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: AppTextStyles.body(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _uploadingAvatar = true);
      final success = await ref.read(authProvider.notifier).updateAvatar(null);
      setState(() => _uploadingAvatar = false);

      if (mounted) {
        showNeuSnack(
          context,
          success
              ? 'Profile picture removed.'
              : 'Failed to remove profile picture.',
          tone: NeuToneKind.success,
        );
      }
    }
  }

  void _showAvatarOptions(bool hasAvatar) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                'Upload Photo',
                style: AppTextStyles.body(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _changeAvatar();
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Remove Current Photo',
                  style: AppTextStyles.body(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.grey),
              title: Text(
                'Cancel',
                style: AppTextStyles.body(color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _businessNameController = TextEditingController(
      text: user?.businessName ?? '',
    );
    _businessDescController = TextEditingController(
      text: user?.businessDescription ?? '',
    );
    final initialCategory = user?.businessCategory;
    if (initialCategory != null &&
        isPredefinedVendorCategory(initialCategory)) {
      _selectedCategory = initialCategory;
      _customCategoryController = TextEditingController();
    } else if (initialCategory != null && initialCategory.isNotEmpty) {
      _selectedCategory = 'Other';
      _customCategoryController = TextEditingController(text: initialCategory);
    } else {
      _selectedCategory = null;
      _customCategoryController = TextEditingController();
    }
    _selectedLocationId = user?.campusLocationId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessDescController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider).user;
      final isVendor = user?.isVendor == true || user?.isPendingVendor == true;

      if (isVendor && _selectedCategory == 'Other') {
        final customCat = _customCategoryController.text.trim();
        if (customCat.isEmpty) {
          showNeuSnack(
            context,
            'Please specify your store category.',
            tone: NeuToneKind.error,
          );
          return;
        }
        if (customCat.length > 60) {
          showNeuSnack(
            context,
            'Store category must be at most 60 characters.',
            tone: NeuToneKind.error,
          );
          return;
        }
      }

      final resolvedCategory = _selectedCategory == 'Other'
          ? _customCategoryController.text.trim()
          : _selectedCategory;

      final success = await ref
          .read(authProvider.notifier)
          .updateProfile(
            _nameController.text,
            _emailController.text,
            phoneNumber: _phoneController.text,
            businessName: isVendor ? _businessNameController.text : null,
            businessCategory: isVendor ? resolvedCategory : null,
            businessDescription: isVendor ? _businessDescController.text : null,
            campusLocationId: isVendor ? _selectedLocationId : null,
          );

      if (!mounted) return;

      final errorMessage = ref.read(authProvider).errorMessage;

      showNeuSnack(
        context,
        success
            ? (isVendor
                  ? 'Vendor details updated successfully.'
                  : 'Profile updated successfully!')
            : (isVendor
                  ? 'Unable to update vendor details.'
                  : (errorMessage ?? 'Profile update failed.')),
        tone: NeuToneKind.success,
      );

      if (success) {
        ref.invalidate(vendorProvider);
        if (context.mounted) {
          context.pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isVendor = user?.isVendor == true || user?.isPendingVendor == true;
    final locationsAsync = ref.watch(campusLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: const CustomAppBar(title: 'Edit Profile'),
      body: Container(
        decoration: BoxDecoration(color: AppColors.base),
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

                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: user?.isAdmin == true
                              ? null
                              : () =>
                                    _showAvatarOptions(user?.avatarUrl != null),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: user?.avatarUrl == null
                                  ? AppColors.primaryGradient
                                  : null,
                              color: user?.avatarUrl != null
                                  ? AppColors.base
                                  : null,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.border,
                                width: 3,
                              ),
                              image: user?.avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(user!.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: user?.avatarUrl == null
                                ? Center(
                                    child: Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text[0]
                                                .toUpperCase()
                                          : 'U',
                                      style: AppTextStyles.display(
                                        fontSize: 36,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (_uploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        if (user?.isAdmin != true)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  _showAvatarOptions(user?.avatarUrl != null),
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

                  // Personal info
                  NeuCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    accent: AppColors.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isVendor) ...[
                          Text(
                            'Personal Info',
                            style: AppTextStyles.subHead(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        NeuTextField(
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          prefixIcon: Icons.person_outline_rounded,
                          controller: _nameController,
                          readOnly: user?.isAdmin == true,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter name' : null,
                        ),
                        const SizedBox(height: 20),
                        NeuTextField(
                          labelText: 'Email Address',
                          hintText: 'yourname@email.com',
                          prefixIcon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: user?.isAdmin == true,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 20),
                        NeuTextField(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 09XXXXXXXXX',
                          prefixIcon: Icons.phone_android_rounded,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          readOnly: user?.isAdmin == true,
                          validator: RegisterController.validatePhone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08),

                  // Vendor-only section
                  if (isVendor) ...[
                    const SizedBox(height: 16),
                    NeuCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(24),
                      accent: AppColors.accent.withValues(alpha: 0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.accent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Business Info',
                                style: AppTextStyles.subHead(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          NeuTextField(
                            labelText: 'Business Name',
                            hintText: 'e.g. UCLM Canteen Express',
                            prefixIcon: Icons.storefront_outlined,
                            controller: _businessNameController,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter business name'
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // Category dropdown
                          DropdownButtonFormField<String>(
                            initialValue:
                                vendorCategories.contains(_selectedCategory)
                                ? _selectedCategory
                                : (_selectedCategory == null ? null : 'Other'),
                            dropdownColor: AppColors.base,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.category_outlined,
                                color: AppColors.textSecondary,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            items: vendorCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: AppTextStyles.body(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                            style: AppTextStyles.body(
                              color: AppColors.textPrimary,
                            ),
                            hint: Text(
                              'Select category',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (_selectedCategory == 'Other') ...[
                            const SizedBox(height: 20),
                            NeuTextField(
                              labelText: 'Specify Store Category',
                              hintText: 'Enter your store category',
                              prefixIcon: Icons.edit_note_rounded,
                              controller: _customCategoryController,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(60),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Campus location dropdown
                          locationsAsync.when(
                            data: (locations) =>
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedLocationId,
                                  dropdownColor: AppColors.base,
                                  decoration: InputDecoration(
                                    labelText: 'Campus Location',
                                    labelStyle: AppTextStyles.body(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surfaceRaised,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  items: locations
                                      .map(
                                        (l) => DropdownMenuItem(
                                          value: l.id,
                                          child: Text(
                                            l.name,
                                            style: AppTextStyles.body(
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedLocationId = v),
                                  style: AppTextStyles.body(
                                    color: AppColors.textPrimary,
                                  ),
                                  hint: Text(
                                    'Select location',
                                    style: AppTextStyles.body(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            loading: () => const LinearProgressIndicator(
                              color: AppColors.primary,
                            ),
                            error: (err, stack) => Text(
                              'Could not load locations',
                              style: AppTextStyles.body(
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          NeuTextField(
                            labelText: 'Description (optional)',
                            hintText: 'Brief description of your business',
                            prefixIcon: Icons.description_outlined,
                            controller: _businessDescController,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08),
                  ],

                  if (user?.isAdmin != true) ...[
                    const SizedBox(height: 24),
                    NeuButton(
                      text: 'Save Changes',
                      onPressed: _handleSave,
                      icon: Icons.check_circle_outline_rounded,
                    ).animate().fadeIn(delay: 250.ms),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
