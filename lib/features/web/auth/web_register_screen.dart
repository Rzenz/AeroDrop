import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/vendor_categories.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/widgets/neu_feedback.dart';
import '../web_breakpoints.dart';
import '../web_tokens.dart';
import '../../auth/presentation/controllers/register_controller.dart';
import '../../auth/widgets/auth_kit.dart';

class WebRegisterScreen extends ConsumerStatefulWidget {
  const WebRegisterScreen({super.key, this.asVendor = false});

  /// Opens on the vendor application, from `/register?role=vendor` — the
  /// landing page's "Apply as a campus vendor" and the vendor sign-in link.
  final bool asVendor;

  @override
  ConsumerState<WebRegisterScreen> createState() => _WebRegisterScreenState();
}

class _WebRegisterScreenState extends ConsumerState<WebRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role Selection
  late bool _isVendorRole = widget.asVendor;
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
  final _latController = TextEditingController(text: '10.325210');
  final _lngController = TextEditingController(text: '123.953201');

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
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
        final validation = await ImageUtils.validateImage(image);
        if (!validation.isValid) {
          _showErrorDialog(
            'Invalid Image',
            validation.errorMessage ??
                'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
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
    if (!isValidEmail(email)) {
      _showErrorDialog('Invalid Email', 'Please enter a valid email address.');
      return false;
    }
    final phone = _phoneController.text.trim();
    try {
      normalizePhoneNumber(phone);
    } catch (_) {
      _showErrorDialog(
        'Phone Number Format',
        'Please enter a valid phone number (e.g. 09123456789 or +639123456789).',
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WebInk.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WebInk.rule),
        ),
        icon: const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 28,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: WebType.entry(WebBreak.compact).copyWith(fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: WebType.body().copyWith(fontSize: 14.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [AuthTextLink(label: 'OK', onTap: () => Navigator.pop(ctx))],
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
          context.push(
            '/email-sent',
            extra: <String, String>{
              'email': email,
              'phone': phone,
              'role': 'vendor',
              'type': 'verification',
            },
          );
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
        showNeuSnack(
          context,
          'You must accept the terms & conditions.',
          tone: NeuToneKind.error,
        );
        return;
      }

      FocusScope.of(context).unfocus();
      final emailText = _emailController.text.trim();
      final phoneText = _phoneController.text.trim();
      final success = await ref
          .read(authProvider.notifier)
          .register(
            _nameController.text,
            emailText,
            _passwordController.text,
            'user',
            phoneText,
          );

      if (mounted) {
        if (success) {
          context.push(
            '/email-sent',
            extra: <String, String>{
              'email': emailText,
              'phone': phoneText,
              'role': 'user',
              'type': 'verification',
            },
          );
        } else {
          final errorMsg =
              ref.read(authProvider).errorMessage ?? 'Registration failed.';
          showNeuSnack(context, errorMsg, tone: NeuToneKind.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    var i = 0;
    Widget row(Widget child) => child.authReveal(context, i++);

    return AuthShell(
      vendor: _isVendorRole,
      formWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            AuthHeading(
              title: _isVendorRole ? 'Apply to sell' : 'Create your account',
              subtitle: _isVendorRole
                  ? 'Register your store and start taking drone orders.'
                  : 'Order from campus canteens and have it flown to you.',
            ),
          ),
          SizedBox(height: context.authGap(24)),
          // Which kind of account. It swaps the whole form underneath, so it
          // sits at the top and looks like a choice, not a filter.
          row(
            AuthSegmented(
              options: const ['Customer', 'Vendor'],
              icons: const [
                Icons.person_outline_rounded,
                Icons.storefront_outlined,
              ],
              selectedIndex: _isVendorRole ? 1 : 0,
              onSelected: (i) => setState(() => _isVendorRole = i == 1),
            ),
          ),
          SizedBox(height: context.authGap(28)),
          row(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(_isVendorRole),
                child: _isVendorRole
                    ? _buildVendorWizard()
                    : _buildUserForm(isLoading),
              ),
            ),
          ),
          SizedBox(height: context.authGap(28)),
          row(const WebRule()),
          SizedBox(height: context.authGap(20)),
          row(
            AuthSwitchPrompt(
              question: 'Already have an account?',
              action: 'Sign in',
              // Pop back to sign-in when that is where this came from;
              // otherwise (opened from a link) go there.
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go(_isVendorRole ? '/login?role=vendor' : '/login'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Customer form ─────────────────────────────────────────────────────────

  Widget _buildUserForm(bool isLoading) {
    final gap = context.authGap(18);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPair(
              gap: gap,
              first: AuthField(
                labelText: 'Full name',
                hintText: 'Your name',
                prefixIcon: Icons.person_outline_rounded,
                controller: _nameController,
                validator: RegisterController.validateName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              second: AuthField(
                labelText: 'Phone number',
                hintText: '09XX XXX XXXX',
                prefixIcon: Icons.phone_iphone_rounded,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: RegisterController.validatePhone,
                textInputAction: TextInputAction.next,
                inputFormatters: const [PhoneInputFormatter()],
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
            ),
            SizedBox(height: gap),
            AuthField(
              labelText: 'Email',
              hintText: 'yourname@email.com',
              prefixIcon: Icons.mail_outline_rounded,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: RegisterController.validateEmail,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            SizedBox(height: gap),
            ..._passwordFields(),
            SizedBox(height: context.authGap(10)),
            AuthCheck(
              value: _acceptTerms,
              label:
                  'I agree to the AeroDrop Terms of Service and Privacy '
                  'Policy.',
              onChanged: (v) => setState(() => _acceptTerms = v),
            ),
            SizedBox(height: context.authGap(16)),
            AuthButton(
              text: 'Create account',
              isLoading: isLoading,
              onPressed: !isValidPhoneNumber(_phoneController.text) || isLoading
                  ? null
                  : _handleRegister,
            ),
          ],
        ),
      ),
    );
  }

  /// Password and confirmation side by side, with one strength line under
  /// both. Shared by the customer form and the vendor owner step.
  List<Widget> _passwordFields({bool vendor = false}) => [
    AuthPair(
      gap: context.authGap(18),
      first: AuthField(
        labelText: vendor ? 'Create a password' : 'Password',
        hintText: 'At least 8 characters',
        prefixIcon: Icons.lock_outline_rounded,
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
        validator: vendor ? null : RegisterController.validatePassword,
        suffixIcon: AuthObscureToggle(
          obscured: _obscurePassword,
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      second: AuthField(
        labelText: 'Confirm password',
        hintText: 'Type it again',
        prefixIcon: Icons.lock_outline_rounded,
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
        validator: vendor
            ? null
            : (val) {
                if (val == null || val.isEmpty) {
                  return 'Confirm your password';
                }
                if (val != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
        suffixIcon: AuthObscureToggle(
          obscured: _obscureConfirmPassword,
          onPressed: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
      ),
    ),
    SizedBox(height: context.authGap(10)),
    AuthPasswordMeter(password: _passwordController.text),
  ];

  // ─── Vendor application ────────────────────────────────────────────────────

  static const _stepLabels = ['Store', 'Owner', 'Location', 'Review'];

  Widget _buildVendorWizard() {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSteps(labels: _stepLabels, current: _vendorStep),
        SizedBox(height: context.authGap(28)),
        // Steps slide in the direction of travel: forward from the right,
        // back from the left, so the order of the application is spatial.
        AnimatedSwitcher(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_vendorStep);
            final dx = (incoming ? 0.06 : -0.06) * _travel;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_vendorStep),
            child: _buildStepContent(),
          ),
        ),
        SizedBox(height: context.authGap(28)),
        Row(
          children: [
            if (_vendorStep > 1) ...[
              Expanded(
                child: AuthButton(
                  text: 'Back',
                  icon: Icons.arrow_back_rounded,
                  variant: AuthButtonVariant.secondary,
                  onPressed: () => _goToStep(_vendorStep - 1),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: _vendorStep == 4
                  ? AuthButton(
                      text: 'Submit application',
                      isLoading: _vendorSubmitted,
                      onPressed: _handleRegister,
                    )
                  : AuthButton(
                      text: 'Continue',
                      onPressed:
                          (_vendorStep == 2 &&
                              !isValidPhoneNumber(_phoneController.text))
                          ? null
                          : () {
                              if (_vendorStep == 1 && _validateStep1()) {
                                _goToStep(2);
                              } else if (_vendorStep == 2 && _validateStep2()) {
                                _goToStep(3);
                              } else if (_vendorStep == 3 && _validateStep3()) {
                                _goToStep(4);
                              }
                            },
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// +1 when the last move went forward, -1 when it went back.
  int _travel = 1;

  void _goToStep(int step) => setState(() {
    _travel = step > _vendorStep ? 1 : -1;
    _vendorStep = step;
  });

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

  /// The step's name and what it is for. On a short window the line under
  /// it steps aside — the step bar above already names the step.
  Widget _stepTitle(String title, String subtitle) {
    final short = context.authShort;
    return Padding(
      padding: EdgeInsets.only(bottom: context.authGap(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: WebType.entry(WebBreak.compact)),
          if (!short) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: WebType.body().copyWith(fontSize: 14.5)),
          ],
        ],
      ),
    );
  }

  // Step 1: the store.
  Widget _buildStep1BusinessInfo() {
    final gap = context.authGap(18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'Your store',
          'What students see when they browse campus vendors.',
        ),
        AuthPair(
          gap: gap,
          first: AuthField(
            labelText: 'Store name',
            hintText: 'Your store\'s name',
            prefixIcon: Icons.storefront_outlined,
            controller: _businessNameController,
            textInputAction: TextInputAction.next,
          ),
          second: AuthDropdown<String>(
            label: 'Store category',
            value: vendorCategories.contains(_businessCategory)
                ? _businessCategory
                : 'Other',
            items: [
              for (final cat in vendorCategories)
                DropdownMenuItem(value: cat, child: Text(cat)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _businessCategory = val);
            },
          ),
        ),
        if (_businessCategory == 'Other') ...[
          SizedBox(height: gap),
          AuthField(
            labelText: 'Your category',
            hintText: 'e.g. Stationery',
            prefixIcon: Icons.edit_outlined,
            controller: _customCategoryController,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
          ),
        ],
        SizedBox(height: gap),
        AuthField(
          labelText: 'Description (optional)',
          hintText: 'What you sell, in a sentence or two',
          prefixIcon: Icons.notes_rounded,
          controller: _businessDescController,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: gap),
        _LogoPicker(
          file: _selectedLogoFile,
          onPick: () {
            HapticFeedback.lightImpact();
            _pickLogo();
          },
          onRemove: () => setState(() => _selectedLogoFile = null),
        ),
      ],
    );
  }

  // Step 2: the person who runs it, and their sign-in.
  Widget _buildStep2OwnerInfo() {
    final gap = context.authGap(18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'You',
          'The owner account you sign in with to manage the store.',
        ),
        AuthPair(
          gap: gap,
          first: AuthField(
            labelText: 'Owner full name',
            hintText: 'Your name',
            prefixIcon: Icons.person_outline_rounded,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          second: AuthField(
            labelText: 'Phone number',
            hintText: '09XX XXX XXXX',
            prefixIcon: Icons.phone_iphone_rounded,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: const [PhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
        ),
        SizedBox(height: gap),
        AuthField(
          labelText: 'Email',
          hintText: 'yourname@email.com',
          prefixIcon: Icons.mail_outline_rounded,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        SizedBox(height: gap),
        ..._passwordFields(vendor: true),
      ],
    );
  }

  // Step 3: where on campus the drone collects from.
  Widget _buildStep3Location() {
    final campusLocationsAsync = ref.watch(campusLocationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'Where you are',
          'The building the drone collects your orders from. Choosing one '
              'fills in its coordinates.',
        ),
        campusLocationsAsync.when(
          loading: () => const AuthWell(
            label: 'Campus building',
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WebInk.accent,
              ),
            ),
          ),
          error: (err, stack) => AuthWell(
            label: 'Campus building',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't load campus buildings.",
                    style: WebType.body(
                      color: AppColors.danger,
                    ).copyWith(fontSize: 14),
                  ),
                ),
                AuthTextLink(
                  label: 'Retry',
                  onTap: () => ref.invalidate(campusLocationsProvider),
                ),
              ],
            ),
          ),
          data: (locations) {
            if (locations.isEmpty) {
              return AuthWell(
                label: 'Campus building',
                child: Text(
                  'No campus buildings are set up yet.',
                  style: WebType.body().copyWith(fontSize: 14),
                ),
              );
            }

            // First visit to this step: start on the first building.
            if (_selectedCampusLocation == null) {
              _selectedCampusLocation = locations.first;
              _latController.text = locations.first.latitude.toString();
              _lngController.text = locations.first.longitude.toString();
            }

            return AuthDropdown<CampusLocation>(
              label: 'Campus building',
              value: _selectedCampusLocation,
              items: [
                for (final loc in locations)
                  DropdownMenuItem(value: loc, child: Text(loc.name)),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedCampusLocation = val;
                  _latController.text = val.latitude.toString();
                  _lngController.text = val.longitude.toString();
                });
              },
            );
          },
        ),
        SizedBox(height: context.authGap(18)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AuthField(
                labelText: 'Latitude',
                hintText: '10.3252',
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthField(
                labelText: 'Longitude',
                hintText: '123.9532',
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.authGap(10)),
        Text(
          'Adjust them only if your counter is not at the building entrance.',
          style: WebType.meta().copyWith(fontSize: 12.5, height: 1.5),
        ),
      ],
    );
  }

  // Step 4: one look at everything before it goes to an administrator.
  Widget _buildStep4Review() {
    String orNone(String v) => v.trim().isEmpty ? 'Not given' : v.trim();
    final category = _businessCategory == 'Other'
        ? _customCategoryController.text
        : _businessCategory;
    final gap = context.authGap(10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'Check your application',
          'An administrator reviews it before your store opens.',
        ),
        _ReviewLine(
          title: 'Store',
          onEdit: () => _goToStep(1),
          values: [
            orNone(_businessNameController.text),
            orNone(category),
            _selectedLogoFile == null ? 'No logo' : 'Logo added',
          ],
        ),
        SizedBox(height: gap),
        _ReviewLine(
          title: 'Owner',
          onEdit: () => _goToStep(2),
          values: [
            orNone(_nameController.text),
            orNone(_emailController.text),
            orNone(_phoneController.text),
          ],
        ),
        SizedBox(height: gap),
        _ReviewLine(
          title: 'Location',
          onEdit: () => _goToStep(3),
          values: [
            _selectedCampusLocation?.name ?? 'No building chosen',
            '${_latController.text}, ${_lngController.text}',
          ],
        ),
        SizedBox(height: context.authGap(12)),
        AuthCheck(
          value: _acceptTerms,
          label:
              'The details above are correct, and I agree to the AeroDrop '
              'Terms of Service.',
          onChanged: (v) => setState(() => _acceptTerms = v),
        ),
      ],
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'Logo (optional)',
      style: WebType.meta(color: WebInk.textSoft).copyWith(fontSize: 13),
    );

    if (file == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'Choose a logo image',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPick,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AuthInk.field,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AuthInk.fieldEdge),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: WebInk.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Choose an image · JPG, PNG or WebP',
                          style: WebType.action(
                            color: WebInk.text,
                          ).copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AuthInk.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthInk.fieldEdge),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FutureBuilder<Uint8List>(
                    future: file!.readAsBytes(),
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                        : const ColoredBox(color: WebInk.raised),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WebType.action(
                        color: WebInk.text,
                      ).copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<int>(
                      future: file!.length(),
                      builder: (context, snapshot) => Text(
                        snapshot.hasData
                            ? '${(snapshot.data! / 1024).toStringAsFixed(1)} KB'
                            : '',
                        style: WebType.meta(),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Change logo',
                onPressed: onPick,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: WebInk.textSoft,
                  size: 19,
                ),
              ),
              IconButton(
                tooltip: 'Remove logo',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One section of the review: its title and an Edit link back to its step,
/// then the section's values on one wrapping line, separated by middots.
/// Values only — "Annex Canteen · Cafe · Logo added" reads without labels,
/// and keeps the whole application on one screen.
class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.title,
    required this.values,
    required this.onEdit,
  });

  final String title;
  final List<String> values;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 12),
      decoration: BoxDecoration(
        color: AuthInk.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebInk.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: WebType.meta(
                    color: WebInk.textSoft,
                  ).copyWith(fontSize: 12.5),
                ),
              ),
              AuthTextLink(label: 'Edit', onTap: onEdit),
            ],
          ),
          Text(
            values.join('  ·  '),
            style: WebType.body(
              color: WebInk.text,
            ).copyWith(fontSize: 14.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
