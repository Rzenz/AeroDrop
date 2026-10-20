import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/vendor_categories.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/utils/phone_input_formatter.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../../../core/widgets/wide_shell.dart';
import '../../../auth/presentation/controllers/register_controller.dart';
import '../web_kit.dart';

String _area(BuildContext context) {
  final p = GoRouterState.of(context).uri.path;
  if (p.startsWith('/vendor')) return 'vendor';
  if (p.startsWith('/admin')) return 'admin';
  return 'user';
}

// ─── Profile ─────────────────────────────────────────────────────────────────

/// The customer's account at a glance: who they are, what they have ordered,
/// and every account task one click away.
class WebProfilePage extends ConsumerWidget {
  const WebProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final orders = ref.watch(orderProvider).orders;
    final delivered = orders
        .where((o) => o.effectiveStatus == 'delivered')
        .toList();
    final spent = delivered.fold<double>(0, (s, o) => s + o.totalAmount);
    final name = user?.name ?? 'Your account';

    final identity = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        children: [
          const SizedBox(height: 6),
          NeuSurface(
            depth: NeuDepth.low,
            borderRadius: BorderRadius.circular(60),
            padding: const EdgeInsets.all(6),
            child: WideAvatar(name: name, url: user?.avatarUrl, size: 96),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: WebText.title(size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: WebText.body(size: 14),
          ),
          if ((user?.phoneNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(user!.phoneNumber!, style: WebText.body(size: 14)),
          ],
          const SizedBox(height: 18),
          WebButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            expand: true,
            onPressed: () => context.push('/user/profile/edit'),
          ),
        ],
      ),
    );

    Widget link(
      IconData icon,
      String title,
      String detail,
      VoidCallback onTap,
    ) => WebHoverCard(
      onTap: onTap,
      semanticLabel: '$title. $detail',
      child: Row(
        children: [
          NeuSurface(
            style: NeuStyle.inset,
            color: AppColors.surfaceSunken,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(14),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: AppColors.accentText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WebText.label(size: 14.5)),
                Text(detail, style: WebText.body(size: 12.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebGrid(
          minTile: 200,
          maxColumns: 3,
          children: [
            WebStat(
              label: 'Orders placed',
              value: '${orders.length}',
              icon: Icons.receipt_long_outlined,
              onTap: () => context.go('/user/orders'),
            ),
            WebStat(
              label: 'Delivered',
              value: '${delivered.length}',
              icon: Icons.where_to_vote_outlined,
              tone: AppColors.success,
            ),
            WebStat(
              label: 'Spent',
              value: WebText.peso(spent),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text('Account', style: WebText.title(size: 18)),
        const SizedBox(height: 14),
        WebGrid(
          minTile: 280,
          maxColumns: 2,
          gap: 16,
          children: [
            link(
              Icons.person_outline_rounded,
              'Profile details',
              'Name, phone and photo',
              () => context.push('/user/profile/edit'),
            ),
            link(
              Icons.lock_reset_rounded,
              'Password',
              'Change the password you sign in with',
              () => context.push('/user/profile/change-password'),
            ),
            link(
              Icons.settings_outlined,
              'Settings',
              'Appearance and sign-in email',
              () => context.push('/user/settings'),
            ),
            link(
              Icons.notifications_none_rounded,
              'Notifications',
              'Order and flight updates',
              () => context.go('/user/notifications'),
            ),
            link(
              Icons.support_agent_rounded,
              'Help and support',
              'Ask the team about an order',
              () => context.push('/shared/help'),
            ),
            link(
              Icons.info_outline_rounded,
              'About AeroDrop',
              'The project and the people behind it',
              () => context.push('/shared/about'),
            ),
          ],
        ),
      ],
    );

    return WebPage(
      title: 'Profile',
      subtitle: 'Your account and your orders.',
      actions: [
        WebButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          kind: WebButtonKind.secondary,
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
      ],
      children: [
        WebSplit(
          main: main,
          side: identity,
          sideWidth: 340,
          sideFirstWhenStacked: true,
        ),
      ],
    );
  }
}

// ─── Edit profile ────────────────────────────────────────────────────────────

/// Profile details for a customer — and, for a vendor, the store details too.
/// Saves through the same calls as the app.
class WebEditProfilePage extends ConsumerStatefulWidget {
  const WebEditProfilePage({super.key});

  @override
  ConsumerState<WebEditProfilePage> createState() => _WebEditProfilePageState();
}

class _WebEditProfilePageState extends ConsumerState<WebEditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _business;
  late final TextEditingController _description;
  late final TextEditingController _customCategory;
  String? _category;
  String? _location;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phoneNumber ?? '');
    _business = TextEditingController(text: u?.businessName ?? '');
    _description = TextEditingController(text: u?.businessDescription ?? '');
    final c = u?.businessCategory;
    if (c != null && isPredefinedVendorCategory(c)) {
      _category = c;
      _customCategory = TextEditingController();
    } else if (c != null && c.isNotEmpty) {
      _category = 'Other';
      _customCategory = TextEditingController(text: c);
    } else {
      _customCategory = TextEditingController();
    }
    _location = u?.campusLocationId;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _business,
      _description,
      _customCategory,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        _area(context) == 'vendor' ? '/vendor/profile' : '/user/profile',
      );
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImageUtils.pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
        title: 'Adjust profile picture',
        isCircle: true,
      );
      if (image == null) return;
      final check = await ImageUtils.validateImage(image);
      if (!check.isValid) {
        if (!mounted) return;
        showNeuSnack(
          context,
          check.errorMessage ?? 'Choose a JPG, PNG or WebP image.',
          tone: NeuToneKind.error,
        );
        return;
      }
      setState(() => _uploading = true);
      final ok = await ref.read(authProvider.notifier).updateAvatar(image);
      if (ok) {
        ref.invalidate(vendorProvider);
        ref.invalidate(productProvider);
      }
      if (!mounted) return;
      setState(() => _uploading = false);
      showNeuSnack(
        context,
        ok
            ? 'Profile picture updated.'
            : (ref.read(authProvider).errorMessage ??
                  'The picture could not be uploaded.'),
        tone: ok ? NeuToneKind.success : NeuToneKind.error,
      );
    } catch (e) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Remove your picture?',
      message: 'Your initial shows in its place.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _uploading = true);
    final done = await ref.read(authProvider.notifier).updateAvatar(null);
    if (done) {
      ref.invalidate(vendorProvider);
      ref.invalidate(productProvider);
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    showNeuSnack(
      context,
      done ? 'Profile picture removed.' : 'The picture could not be removed.',
      tone: done ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = ref.read(authProvider).user;
    final vendor = u?.isVendor == true || u?.isPendingVendor == true;
    if (vendor && _category == 'Other') {
      final c = _customCategory.text.trim();
      if (c.isEmpty || c.length > 60) {
        showNeuSnack(
          context,
          c.isEmpty
              ? 'Name your store category.'
              : 'Keep the store category under 60 characters.',
          tone: NeuToneKind.error,
        );
        return;
      }
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(authProvider.notifier)
        .updateProfile(
          _name.text,
          _email.text,
          phoneNumber: _phone.text,
          businessName: vendor ? _business.text : null,
          businessCategory: vendor
              ? (_category == 'Other' ? _customCategory.text.trim() : _category)
              : null,
          businessDescription: vendor ? _description.text : null,
          campusLocationId: vendor ? _location : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showNeuSnack(
      context,
      ok
          ? (vendor ? 'Store details saved.' : 'Profile saved.')
          : (ref.read(authProvider).errorMessage ??
                'The changes could not be saved.'),
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
    if (ok) {
      ref.invalidate(vendorProvider);
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authProvider).user;
    final vendor = u?.isVendor == true || u?.isPendingVendor == true;
    final admin = u?.isAdmin == true;
    final hasAvatar = (u?.avatarUrl ?? '').isNotEmpty;
    final locations = ref.watch(campusLocationsProvider);

    final photo = WebPanel(
      title: 'Photo',
      child: Column(
        children: [
          NeuSurface(
            borderRadius: BorderRadius.circular(70),
            padding: const EdgeInsets.all(6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                WideAvatar(name: u?.name ?? '', url: u?.avatarUrl, size: 116),
                if (_uploading)
                  const SizedBox(
                    width: 116,
                    height: 116,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          WebButton(
            label: hasAvatar ? 'Change photo' : 'Upload a photo',
            icon: Icons.photo_library_outlined,
            kind: WebButtonKind.secondary,
            expand: true,
            onPressed: _uploading ? null : _pickAvatar,
          ),
          if (hasAvatar) ...[
            const SizedBox(height: 10),
            WebButton(
              label: 'Remove photo',
              kind: WebButtonKind.ghost,
              expand: true,
              onPressed: _uploading ? null : _removeAvatar,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'JPG, PNG or WebP. It is cropped to a circle.',
            textAlign: TextAlign.center,
            style: WebText.body(size: 12.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );

    Widget pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 560
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b),
              ],
            )
          : Column(children: [a, const SizedBox(height: 16), b]),
    );

    final personal = WebPanel(
      title: 'Personal details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebField(
            label: 'Full name',
            controller: _name,
            icon: Icons.person_outline_rounded,
            readOnly: admin,
            validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          pair(
            WebField(
              label: 'Email',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              readOnly: admin,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your email' : null,
            ),
            WebField(
              label: 'Phone',
              controller: _phone,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              readOnly: admin,
              validator: RegisterController.validatePhone,
              inputFormatters: const [PhoneInputFormatter()],
            ),
          ),
        ],
      ),
    );

    final store = !vendor
        ? null
        : WebPanel(
            title: 'Store details',
            subtitle: 'What customers see on your canteen page.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebField(
                  label: 'Store name',
                  controller: _business,
                  icon: Icons.storefront_outlined,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the store name'
                      : null,
                ),
                const SizedBox(height: 16),
                pair(
                  _Select<String>(
                    label: 'Category',
                    value: _category,
                    items: [for (final c in vendorCategories) (c, c)],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  locations.when(
                    loading: () => const WebSkeleton(height: 52, radius: 14),
                    error: (e, _) => Text('Could not load buildings: $e'),
                    data: (list) => _Select<String>(
                      label: 'Building',
                      value: list.any((l) => l.id == _location)
                          ? _location
                          : null,
                      items: [for (final l in list) (l.id, l.name)],
                      onChanged: (v) => setState(() => _location = v),
                    ),
                  ),
                ),
                if (_category == 'Other') ...[
                  const SizedBox(height: 16),
                  WebField(
                    label: 'Your category',
                    controller: _customCategory,
                    hint: 'e.g. Rice meals',
                  ),
                ],
                const SizedBox(height: 16),
                WebField(
                  label: 'Description',
                  controller: _description,
                  maxLines: 4,
                  hint: 'What you sell, and when you are open.',
                ),
              ],
            ),
          );

    return WebPage(
      title: vendor ? 'Edit store profile' : 'Edit profile',
      back: true,
      onBack: _back,
      maxWidth: 1120,
      actions: [
        WebButton(
          label: 'Save changes',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: admin ? null : _save,
        ),
      ],
      children: [
        Form(
          key: _form,
          child: WebSplit(
            sideWidth: 300,
            sideFirstWhenStacked: true,
            side: photo,
            main: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                personal,
                if (store != null) ...[const SizedBox(height: 22), store],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A labelled select in an input well.
class _Select<T> extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: WebText.label(size: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          style: WebText.body(size: 15, color: AppColors.textPrimary),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          decoration: webInputDecoration(hint: 'Choose…'),
          items: [
            for (final (v, l) in items)
              DropdownMenuItem(
                value: v,
                child: Text(l, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─── Password ────────────────────────────────────────────────────────────────

class WebChangePasswordPage extends StatefulWidget {
  const WebChangePasswordPage({super.key});

  @override
  State<WebChangePasswordPage> createState() => _WebChangePasswordPageState();
}

class _WebChangePasswordPageState extends State<WebChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _show = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final email = SupabaseService.isConfigured
        ? SupabaseService.client.auth.currentUser?.email
        : null;
    if (email == null || email.isEmpty) {
      showNeuSnack(
        context,
        'You need to be signed in.',
        tone: NeuToneKind.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // The current password is checked first, as the app does.
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: _old.text.trim(),
      );
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _new.text.trim()),
      );
      if (!mounted) return;
      showNeuSnack(context, 'Password changed.', tone: NeuToneKind.success);
      context.pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      showNeuSnack(
        context,
        m.contains('invalid login credentials')
            ? 'The current password is not right.'
            : (m.contains('weak')
                  ? 'The new password is too weak.'
                  : 'The password could not be changed. Try again.'),
        tone: NeuToneKind.error,
      );
    } catch (_) {
      if (mounted) {
        showNeuSnack(
          context,
          'The password could not be changed. Try again.',
          tone: NeuToneKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      tooltip: _show ? 'Hide passwords' : 'Show passwords',
      icon: Icon(
        _show ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 19,
        color: AppColors.textSecondary,
      ),
      onPressed: () => setState(() => _show = !_show),
    );
    return WebPage(
      title: 'Change password',
      subtitle: 'You stay signed in on this device.',
      back: true,
      maxWidth: 640,
      children: [
        WebPanel(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebField(
                  label: 'Current password',
                  controller: _old,
                  obscure: !_show,
                  icon: Icons.lock_outline_rounded,
                  suffix: eye,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 16),
                WebField(
                  label: 'New password',
                  controller: _new,
                  obscure: !_show,
                  icon: Icons.lock_reset_rounded,
                  helper: 'At least 6 characters.',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 6) return 'Use at least 6 characters';
                    if (v == _old.text) return 'Use a different password';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                WebField(
                  label: 'Confirm new password',
                  controller: _confirm,
                  obscure: !_show,
                  icon: Icons.lock_reset_rounded,
                  validator: (v) =>
                      v != _new.text ? 'The passwords do not match' : null,
                ),
                const SizedBox(height: 22),
                WebButton(
                  label: 'Change password',
                  icon: Icons.check_rounded,
                  expand: true,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Settings ────────────────────────────────────────────────────────────────

/// What can actually be set: how the site looks, the sign-in email, the
/// password, and the policies.
class WebSettingsPage extends ConsumerWidget {
  const WebSettingsPage({super.key});

  Future<void> _changeEmail(BuildContext context) async {
    final email = TextEditingController();
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.base,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Change email address', style: WebText.title(size: 19)),
                  const SizedBox(height: 8),
                  Text(
                    'A confirmation link goes to your current and your new '
                    'address. The change takes effect when both are confirmed.',
                    style: WebText.body(size: 14),
                  ),
                  const SizedBox(height: 18),
                  WebField(
                    label: 'New email address',
                    controller: email,
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Enter an email address';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      WebButton(
                        label: 'Cancel',
                        kind: WebButtonKind.secondary,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 12),
                      WebButton(
                        label: 'Send links',
                        icon: Icons.send_rounded,
                        onPressed: () async {
                          if (!form.currentState!.validate()) return;
                          final to = email.text.trim().toLowerCase();
                          Navigator.pop(ctx);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(email: to),
                            );
                            if (!context.mounted) return;
                            showNeuSnack(
                              context,
                              'Confirmation links sent to $to and your current '
                              'address.',
                              tone: NeuToneKind.info,
                              duration: const Duration(seconds: 8),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            showNeuSnack(
                              context,
                              'The email could not be changed: $e',
                              tone: NeuToneKind.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    email.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    const password = '/user/profile/change-password';

    Widget row(IconData icon, String title, String detail, Widget trailing) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 21, color: AppColors.accentText),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: WebText.label(size: 14.5)),
                    Text(detail, style: WebText.body(size: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        );

    return WebPage(
      title: 'Settings',
      back: true,
      maxWidth: 860,
      children: [
        WebPanel(
          title: 'Appearance',
          child: row(
            Icons.contrast_rounded,
            'Theme',
            'Dark is the AeroDrop default.',
            WebTabs(
              labels: const ['Light', 'Dark', 'System'],
              selected: switch (mode) {
                ThemeMode.light => 0,
                ThemeMode.dark => 1,
                ThemeMode.system => 2,
              },
              onSelected: (i) => ref
                  .read(themeModeProvider.notifier)
                  .setTheme(
                    const [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ][i],
                  ),
            ),
          ),
        ),
        WebPanel(
          title: 'Sign-in and security',
          child: Column(
            children: [
              row(
                Icons.mail_outline_rounded,
                'Email address',
                'Where receipts and sign-in links go.',
                WebButton(
                  label: 'Change',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  onPressed: () => _changeEmail(context),
                ),
              ),
              row(
                Icons.lock_reset_rounded,
                'Password',
                'Change the password you sign in with.',
                WebButton(
                  label: 'Change',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  onPressed: () => context.push(password),
                ),
              ),
            ],
          ),
        ),
        WebPanel(
          title: 'Policies',
          child: Column(
            children: [
              row(
                Icons.privacy_tip_outlined,
                'Privacy policy',
                'What AeroDrop keeps and why.',
                WebButton(
                  label: 'Read',
                  kind: WebButtonKind.ghost,
                  dense: true,
                  onPressed: () => context.push('/shared/privacy-policy'),
                ),
              ),
              row(
                Icons.description_outlined,
                'Terms and conditions',
                'The rules for ordering and flying.',
                WebButton(
                  label: 'Read',
                  kind: WebButtonKind.ghost,
                  dense: true,
                  onPressed: () => context.push('/shared/terms-conditions'),
                ),
              ),
              row(
                Icons.info_outline_rounded,
                'About AeroDrop',
                'The project and its team.',
                WebButton(
                  label: 'Read',
                  kind: WebButtonKind.ghost,
                  dense: true,
                  onPressed: () => context.push('/shared/about'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
