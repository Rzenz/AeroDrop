import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/location_provider.dart';
import 'presentation/controllers/register_controller.dart';
import 'widgets/password_strength_indicator.dart';
import '../../core/widgets/drone_svg_painter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/vendor_categories.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _bgRotateController;

  // Step Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role Selection
  bool _isVendorRole = false;
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Vendor Multi-Step Onboarding Data
  int _vendorStep =
      1; // 1: Business Info, 2: Owner Info, 3: Location, 4: Review
  bool _vendorSubmitted = false;

  // Vendor Step 1: Business Info
  final _businessNameController = TextEditingController();
  final _businessDescController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _businessCategory = 'Cafe';
  XFile? _selectedLogoFile;
  final ImagePicker _picker = ImagePicker();

  // Vendor Step 3: Location Info
  CampusLocation? _selectedCampusLocation;
  final _latController = TextEditingController(text: '10.354215');
  final _lngController = TextEditingController(text: '123.912844');
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _bgRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          _showErrorDialog(
            'File Too Large',
            'Please select an image smaller than 2MB.',
          );
          return;
        }
        setState(() {
          _selectedLogoFile = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
    }
  }

  @override
  void dispose() {
    _bgRotateController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _businessDescController.dispose();
    _customCategoryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // Frontend validations for step progress
  bool _validateStep1() {
    if (_businessNameController.text.trim().isEmpty) {
      _showErrorDialog(
        'Business Name Required',
        'Please enter your store/business name to proceed.',
      );
      return false;
    }
    if (_businessCategory == 'Other') {
      final customCat = _customCategoryController.text.trim();
      if (customCat.isEmpty) {
        _showErrorDialog(
          'Store Category Required',
          'Please specify your store category.',
        );
        return false;
      }
      if (customCat.length > 60) {
        _showErrorDialog(
          'Store Category Too Long',
          'Store category must be at most 60 characters.',
        );
        return false;
      }
    }
    return true;
  }

  bool _validateStep2() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog(
        'Owner Name Required',
        'Please enter the owner full name.',
      );
      return false;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,4}$').hasMatch(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email address.');
      return false;
    }
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showErrorDialog(
        'Phone Number Format',
        'Phone number must be exactly 11 digits.',
      );
      return false;
    }
    final pwd = _passwordController.text;
    if (pwd.length < 6) {
      _showErrorDialog(
        'Password Length',
        'Password must be at least 6 characters.',
      );
      return false;
    }
    if (pwd != _confirmPasswordController.text) {
      _showErrorDialog(
        'Password Mismatch',
        'Your passwords do not match. Please verify and try again.',
      );
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    final lat = _latController.text.trim();
    final lng = _lngController.text.trim();
    if (lat.isEmpty || lng.isEmpty) {
      _showErrorDialog(
        'Coordinates Required',
        'Latitude and longitude coordinates are required for drone dispatch targeting.',
      );
      return false;
    }
    return true;
  }

  void _showErrorDialog(String title, String message) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_isVendorRole) {
      if (!_acceptTerms) {
        _showErrorDialog(
          'Terms of Service',
          'You must agree to the Terms of Service to list your store.',
        );
        return;
      }

      final authState = ref.read(authProvider);
      if (authState.isLoading) return;

      final bizName = _businessNameController.text.trim();
      final ownerName = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final resolvedBusinessCategory = _businessCategory == 'Other'
          ? _customCategoryController.text.trim()
          : _businessCategory;

      if (bizName.isEmpty) {
        _showErrorDialog('Missing Information', 'Business Name is required.');
        return;
      }
      if (ownerName.isEmpty) {
        _showErrorDialog('Missing Information', 'Owner Full Name is required.');
        return;
      }
      if (email.isEmpty) {
        _showErrorDialog('Missing Information', 'Email Address is required.');
        return;
      }
      if (phone.isEmpty) {
        _showErrorDialog('Missing Information', 'Phone Number is required.');
        return;
      }
      if (password.isEmpty) {
        _showErrorDialog('Missing Information', 'Password is required.');
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() => _vendorSubmitted = true);

      final locationId = _selectedCampusLocation?.id;

      final success = await ref
          .read(authProvider.notifier)
          .register(
            ownerName,
            email,
            password,
            'vendor',
            phone,
            businessName: bizName,
            businessCategory: resolvedBusinessCategory,
            businessDescription: _businessDescController.text.trim(),
            campusLocationId: locationId,
            logoFile: _selectedLogoFile,
          );

      if (mounted) {
        setState(() => _vendorSubmitted = false);
        if (success) {
          setState(() {
            _vendorStep = 5; // Go to success view
          });
        } else {
          final errorMsg =
              ref.read(authProvider).errorMessage ?? 'Registration failed.';
          _showErrorDialog('Registration Error', errorMsg);
        }
      }
    } else {
      // User/Student Submit
      final authState = ref.read(authProvider);
      if (authState.isLoading) return;

      if (!_formKey.currentState!.validate()) return;
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You must accept the terms & conditions.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      FocusScope.of(context).unfocus();
      final success = await ref
          .read(authProvider.notifier)
          .register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            'user',
            _phoneController.text,
          );

      if (mounted) {
        if (success) {
          final isUserLoggedIn = ref.read(authProvider).user != null;
          if (isUserLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Registration successful.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            context.go('/user');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Registration successful. Please check your email to confirm your account.',
                ),
                backgroundColor: AppColors.info,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 8),
              ),
            );
            context.go('/login');
          }
        } else {
          final errorMsg =
              ref.read(authProvider).errorMessage ?? 'Registration failed.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // If Vendor registration is completed, show the beautiful Success screen
    if (_isVendorRole && _vendorStep == 5) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background glowing orbs
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Core Scroll Layout
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // App Branding Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AeroDrop',
                            style: AppTextStyles.display(
                              fontSize: 42,
                              letterSpacing: -1.5,
                            ),
                          ).animate().fadeIn().slideX(begin: -0.1),
                          const SizedBox(height: 4),
                          Text(
                            'UCLM DRONE DELIVERY SYSTEM',
                            style: AppTextStyles.subHead(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                            ),
                          ).animate().fadeIn(delay: 100.ms),
                        ],
                      ),
                      Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _bgRotateController,
                                builder: (context, _) {
                                  return SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CustomPaint(
                                      size: const Size(30, 30),
                                      painter: DroneSvgPainter(
                                        animationValue:
                                            _bgRotateController.value,
                                        lineColor: AppColors.bgDark,
                                        accentColor: const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .scale(curve: Curves.elasticOut),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Account Role Switch Card
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RoleTabBtn(
                            label: 'User Registration',
                            icon: Icons.person_rounded,
                            isActive: !_isVendorRole,
                            onTap: () => setState(() => _isVendorRole = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RoleTabBtn(
                            label: 'Vendor Registration',
                            icon: Icons.storefront_rounded,
                            isActive: _isVendorRole,
                            onTap: () => setState(() => _isVendorRole = true),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),

                  // Interactive Form view
                  _isVendorRole
                      ? _buildVendorWizard()
                      : _buildUserForm(authState.isLoading),

                  const SizedBox(height: 28),
                  // Footer Back to Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- USER FORM BUILDER ---
  Widget _buildUserForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'User Signup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Order from vendor outlets and receive drone deliveries.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            CustomTextField(
              labelText: 'Full Name',
              hintText: 'Juan dela Cruz',
              prefixIcon: Icons.person_outline_rounded,
              controller: _nameController,
              validator: RegisterController.validateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),

            CustomTextField(
              labelText: 'Email Address',
              hintText: 'yourname@domain.com',
              prefixIcon: Icons.email_outlined,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  RegisterController.validateEmail(v, UserRole.user),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),

            CustomTextField(
              labelText: 'Phone Number',
              hintText: 'e.g. 09XXXXXXXXX',
              prefixIcon: Icons.phone_android_rounded,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: RegisterController.validatePhone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
            ),
            const SizedBox(height: 18),

            CustomTextField(
              labelText: 'Password',
              hintText: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (val) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: RegisterController.validatePassword,
            ),
            PasswordStrengthIndicator(password: _passwordController.text),
            const SizedBox(height: 12),

            CustomTextField(
              labelText: 'Confirm Password',
              hintText: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onChanged: (val) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Confirm password is required';
                }
                if (val != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Terms
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  activeColor: AppColors.accent,
                  checkColor: AppColors.bgDark,
                  onChanged: (val) =>
                      setState(() => _acceptTerms = val ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I agree to the AeroDrop Terms of Service and Privacy Policy.',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            GradientButton(
              text: 'Register Account',
              isLoading: isLoading,
              onPressed: _handleRegister,
              icon: Icons.rocket_launch_rounded,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }

  // --- VENDOR MULTI-STEP WIZARD ---
  Widget _buildVendorWizard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stepper Progress Header
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vendor Setup Steps',
                    style: AppTextStyles.label(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  Text(
                    'Step $_vendorStep of 4',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Animated progress bar
              Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    width:
                        MediaQuery.of(context).size.width *
                        (_vendorStep / 4.0) *
                        0.75,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Wizard Steps Page Switcher
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _buildStepContent(),
        ),
        const SizedBox(height: 24),

        // Wizard Buttons Row
        Row(
          children: [
            if (_vendorStep > 1)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _vendorStep--),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: const BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            if (_vendorStep > 1) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _vendorStep == 4
                  ? GradientButton(
                      text: 'Submit Application',
                      isLoading: _vendorSubmitted,
                      onPressed: _handleRegister,
                      icon: Icons.check_circle_outline_rounded,
                    )
                  : GradientButton(
                      text: 'Continue',
                      onPressed: () {
                        if (_vendorStep == 1 && _validateStep1()) {
                          setState(() => _vendorStep = 2);
                        } else if (_vendorStep == 2 && _validateStep2()) {
                          setState(() => _vendorStep = 3);
                        } else if (_vendorStep == 3 && _validateStep3()) {
                          setState(() => _vendorStep = 4);
                        }
                      },
                      icon: Icons.arrow_forward_rounded,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // Steps Switcher Implementation
  Widget _buildStepContent() {
    switch (_vendorStep) {
      case 1:
        return _buildStep1BusinessInfo();
      case 2:
        return _buildStep2OwnerInfo();
      case 3:
        return _buildStep3Location();
      case 4:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Business Details
  Widget _buildStep1BusinessInfo() {
    return GlassCard(
      key: const ValueKey('step_1_business'),
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Business Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Status Badge (Preview only)
              Text(
                'Pending Review',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Business Name
          CustomTextField(
            labelText: 'Business Name *',
            hintText: 'e.g. Campus Bites Canteen',
            prefixIcon: Icons.storefront_rounded,
            controller: _businessNameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Short Business Description
          CustomTextField(
            labelText: 'Description',
            hintText: 'Provide details about meals, beverages, items...',
            prefixIcon: Icons.description_outlined,
            controller: _businessDescController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Category Dropdown Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store Category *',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: vendorCategories.contains(_businessCategory)
                        ? _businessCategory
                        : 'Other',
                    dropdownColor: AppColors.cardDark2,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.accent,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: vendorCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _businessCategory = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_businessCategory == 'Other') ...[
            const SizedBox(height: 18),
            CustomTextField(
              labelText: 'Specify Store Category *',
              hintText: 'Enter your store category',
              prefixIcon: Icons.edit_note_rounded,
              controller: _customCategoryController,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
            ),
          ],
          const SizedBox(height: 20),

          // Custom Business Logo Upload Widget (Placeholder only)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Logo Showcase',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 8),
              _selectedLogoFile == null
                  ? GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _pickLogo();
                      },
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.accent,
                                size: 28,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Click to Upload Logo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(File(_selectedLogoFile!.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLogoFile!.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                FutureBuilder<int>(
                                  future: File(
                                    _selectedLogoFile!.path,
                                  ).length(),
                                  builder: (context, snapshot) {
                                    final kb = (snapshot.data ?? 0) / 1024;
                                    return Text(
                                      'Size: ${kb.toStringAsFixed(1)} KB',
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _pickLogo();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedLogoFile = null);
                            },
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 2: Owner / Account Info
  Widget _buildStep2OwnerInfo() {
    return GlassCard(
      key: const ValueKey('step_2_owner'),
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vendor Owner Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          CustomTextField(
            labelText: 'Owner Full Name *',
            hintText: 'e.g. Maria Santos',
            prefixIcon: Icons.person_outline_rounded,
            controller: _nameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          CustomTextField(
            labelText: 'Email Address *',
            hintText: 'yourname@domain.com',
            prefixIcon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          CustomTextField(
            labelText: 'Phone Number *',
            hintText: 'e.g. 09XXXXXXXXX',
            prefixIcon: Icons.phone_android_rounded,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          const SizedBox(height: 18),

          CustomTextField(
            labelText: 'Create Password *',
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onChanged: (val) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          PasswordStrengthIndicator(password: _passwordController.text),
          const SizedBox(height: 12),

          CustomTextField(
            labelText: 'Confirm Password *',
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onChanged: (val) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: Business Location
  Widget _buildStep3Location() {
    final campusLocationsAsync = ref.watch(campusLocationsProvider);
    return GlassCard(
      key: const ValueKey('step_3_location'),
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Business Campus Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Campus Building Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campus Building *',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: campusLocationsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    error: (err, stack) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Failed to load locations',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.accent,
                            size: 18,
                          ),
                          onPressed: () =>
                              ref.invalidate(campusLocationsProvider),
                        ),
                      ],
                    ),
                    data: (locations) {
                      if (locations.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No campus locations found',
                            style: TextStyle(color: Colors.white60),
                          ),
                        );
                      }

                      // Auto-select first location if none is selected
                      if (_selectedCampusLocation == null) {
                        _selectedCampusLocation = locations.first;
                        _latController.text = locations.first.latitude
                            .toString();
                        _lngController.text = locations.first.longitude
                            .toString();
                      }

                      return DropdownButton<CampusLocation>(
                        value: _selectedCampusLocation,
                        dropdownColor: AppColors.cardDark2,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.accent,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items: locations.map((loc) {
                          return DropdownMenuItem<CampusLocation>(
                            value: loc,
                            child: Text(loc.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCampusLocation = val;
                              _latController.text = val.latitude.toString();
                              _lngController.text = val.longitude.toString();
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Latitude Longitude Fields
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  labelText: 'Latitude *',
                  hintText: '10.3541',
                  prefixIcon: Icons.pin_drop_outlined,
                  controller: _latController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  labelText: 'Longitude *',
                  hintText: '123.9124',
                  prefixIcon: Icons.pin_drop_outlined,
                  controller: _lngController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Location Map Preview Placeholder
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Map Preview Target',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: _simulateGetLocation,
                    child: _gettingLocation
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.accent,
                            ),
                          )
                        : const Text(
                            'Get Coordinates',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400',
                    ),
                    fit: BoxFit.cover,
                    opacity: 0.35,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_searching_rounded,
                        color: AppColors.accent,
                        size: 32,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'UCLM Campus Grid Target Lock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _simulateGetLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _gettingLocation = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _gettingLocation = false;
        _latController.text = '10.354188';
        _lngController.text = '123.912351';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Coordinates auto-filled from current position.'),
          backgroundColor: AppColors.primaryLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // STEP 4: Review Summary details
  Widget _buildStep4Review() {
    return GlassCard(
      key: const ValueKey('step_4_review'),
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Review Application Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _vendorStep = 1),
                child: const Text(
                  'Edit Store',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Business Information Block
          _ReviewBlock(
            icon: Icons.storefront_rounded,
            title: 'Store Information',
            items: [
              _ReviewItem(
                label: 'Store Name',
                value: _businessNameController.text,
              ),
              _ReviewItem(
                label: 'Category',
                value: _businessCategory == 'Other'
                    ? _customCategoryController.text.trim()
                    : _businessCategory,
              ),
              _ReviewItem(
                label: 'Description',
                value: _businessDescController.text.isEmpty
                    ? '(No description)'
                    : _businessDescController.text,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Owner Information Block
          _ReviewBlock(
            icon: Icons.person_outline_rounded,
            title: 'Owner Credentials',
            items: [
              _ReviewItem(label: 'Full Name', value: _nameController.text),
              _ReviewItem(label: 'Email', value: _emailController.text),
              _ReviewItem(label: 'Phone', value: _phoneController.text),
            ],
          ),
          const SizedBox(height: 14),

          // Building Information Block
          _ReviewBlock(
            icon: Icons.pin_drop_outlined,
            title: 'Store Location',
            items: [
              _ReviewItem(
                label: 'Campus Building',
                value: _selectedCampusLocation?.name ?? 'Not selected',
              ),
              _ReviewItem(
                label: 'Drone Coordinates',
                value: '${_latController.text}, ${_lngController.text}',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Agree terms selection
          Row(
            children: [
              Checkbox(
                value: _acceptTerms,
                activeColor: AppColors.accent,
                checkColor: AppColors.bgDark,
                onChanged: (val) => setState(() => _acceptTerms = val ?? false),
              ),
              const Expanded(
                child: Text(
                  'I certify that all store and location parameters are correct.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- VENDOR SUCCESS ONBOARDING VIEW ---
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 68,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 28),

              Text(
                'Registration Submitted!',
                style: AppTextStyles.heading(fontSize: 22, color: Colors.white),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 10),

              const Text(
                'Your vendor registration has been submitted.\n\nThe administrator will review your application before your store becomes active on AeroDrop.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 36),

              GradientButton(
                text: 'Return to Login',
                onPressed: () => context.go('/login'),
                icon: Icons.login_rounded,
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.borderDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleTabBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.primaryDark
                  : AppColors.textSecondaryDark,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.primaryDark
                    : AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_ReviewItem> items;
  const _ReviewBlock({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
