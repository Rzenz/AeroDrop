import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/review_provider.dart';
import '../../../../core/providers/vendor_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../../core/widgets/neu_surface.dart';
import '../../web_tokens.dart';
import '../web_kit.dart';

/// The canteen's page about itself: the storefront as customers meet it,
/// the details behind it, and the account links.
class WebVendorProfilePage extends ConsumerStatefulWidget {
  const WebVendorProfilePage({super.key});

  @override
  ConsumerState<WebVendorProfilePage> createState() =>
      _WebVendorProfilePageState();
}

class _WebVendorProfilePageState extends ConsumerState<WebVendorProfilePage> {
  bool _uploading = false;

  Future<void> _changeLogo() async {
    try {
      final image = await ImageUtils.pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
        title: 'Adjust store logo',
        isCircle: false,
      );
      if (image == null || !mounted) return;
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
      final ok = await ref
          .read(authProvider.notifier)
          .updateBusinessLogo(image);
      if (ok) {
        ref.invalidate(vendorProvider);
        ref.invalidate(productProvider);
      }
      if (!mounted) return;
      setState(() => _uploading = false);
      showNeuSnack(
        context,
        ok
            ? 'Store logo updated.'
            : (ref.read(authProvider).errorMessage ??
                  'The logo could not be uploaded.'),
        tone: ok ? NeuToneKind.success : NeuToneKind.error,
      );
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeLogo() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Remove your store logo?',
      message: 'Your store initials show in its place.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _uploading = true);
    final done = await ref.read(authProvider.notifier).updateBusinessLogo(null);
    if (done) {
      ref.invalidate(vendorProvider);
      ref.invalidate(productProvider);
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    showNeuSnack(
      context,
      done ? 'Store logo removed.' : 'The logo could not be removed.',
      tone: done ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authProvider).user;
    if (u == null) {
      return const WebPage(
        title: 'Store profile',
        children: [
          WebEmpty(
            icon: Icons.storefront_outlined,
            title: 'Not signed in',
            message: 'Sign in with your vendor account to see your store.',
          ),
        ],
      );
    }
    final store = (u.businessName?.isNotEmpty ?? false)
        ? u.businessName!
        : u.fullName;
    final location =
        ref
            .watch(campusLocationsProvider)
            .valueOrNull
            ?.where((l) => l.id == u.campusLocationId)
            .firstOrNull
            ?.name ??
        'UCLM Campus';
    final products = ref.watch(vendorProductsProvider).products.length;
    final rating = ref.watch(vendorRatingsSummaryProvider(u.id)).valueOrNull;
    final sky = WebSky.values[store.hashCode.abs() % 4];
    final logo = u.businessLogoUrl;
    final compact = WebLayout.isCompact(context);

    final front = WebPanel(
      depth: NeuDepth.medium,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: compact ? 110 : 150,
            decoration: BoxDecoration(
              gradient: sky.gradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: NeuSurface(
                    depth: NeuDepth.medium,
                    borderRadius: BorderRadius.circular(26),
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 88,
                      height: 88,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: sky.gradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: _uploading
                          ? const CircularProgressIndicator()
                          : (logo == null || logo.isEmpty
                                ? Text(
                                    store.substring(0, 1).toUpperCase(),
                                    style: WebText.display(34, color: sky.ink),
                                  )
                                : Image.network(
                                    logo,
                                    fit: BoxFit.cover,
                                    width: 88,
                                    height: 88,
                                  )),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store, style: WebText.display(compact ? 22 : 26)),
                      const SizedBox(height: 4),
                      Text(location, style: WebText.body(size: 14)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if ((u.businessCategory ?? '').isNotEmpty)
                            WebPill(
                              label: u.businessCategory!,
                              tone: AppColors.accent,
                            ),
                          WebPill(
                            label:
                                '$products ${products == 1 ? 'product' : 'products'}',
                            tone: AppColors.primary,
                          ),
                          WebPill(
                            label: rating != null && rating.totalReviews > 0
                                ? '★ ${rating.averageRating.toStringAsFixed(1)} · ${rating.totalReviews} reviews'
                                : 'No reviews yet',
                            tone: AppColors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    WebButton(
                      label: (logo ?? '').isEmpty
                          ? 'Upload logo'
                          : 'Change logo',
                      icon: Icons.photo_library_outlined,
                      kind: WebButtonKind.secondary,
                      dense: true,
                      onPressed: _uploading ? null : _changeLogo,
                    ),
                    if ((logo ?? '').isNotEmpty)
                      WebButton(
                        label: 'Remove logo',
                        kind: WebButtonKind.ghost,
                        dense: true,
                        onPressed: _uploading ? null : _removeLogo,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final info = WebPanel(
      title: 'Store details',
      action: WebButton(
        label: 'Edit',
        icon: Icons.edit_outlined,
        kind: WebButtonKind.secondary,
        dense: true,
        onPressed: () => context.push('/vendor/profile/edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebKeyValue('Owner', u.fullName),
          WebKeyValue('Building', location),
          WebKeyValue('Email', u.email),
          WebKeyValue('Phone', u.phoneNumber ?? 'Not provided'),
          if ((u.businessDescription ?? '').isNotEmpty) ...[
            const WebGroove(),
            Text('About the store', style: WebText.body(size: 12.5)),
            const SizedBox(height: 4),
            Text(
              u.businessDescription!,
              style: WebText.label(size: 14, weight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );

    Widget link(IconData icon, String title, VoidCallback onTap) =>
        WebHoverCard(
          onTap: onTap,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accentText),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: WebText.label(size: 14.5))),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        );

    final account = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Account', style: WebText.title(size: 17)),
        const SizedBox(height: 12),
        link(
          Icons.lock_reset_rounded,
          'Change password',
          () => context.push('/shared/change-password'),
        ),
        const SizedBox(height: 10),
        link(
          Icons.support_agent_rounded,
          'Help and support',
          () => context.push('/shared/help'),
        ),
        const SizedBox(height: 10),
        link(
          Icons.description_outlined,
          'Terms and conditions',
          () => context.push('/shared/terms-conditions'),
        ),
        const SizedBox(height: 10),
        link(
          Icons.info_outline_rounded,
          'About AeroDrop',
          () => context.push('/shared/about'),
        ),
        const SizedBox(height: 16),
        WebButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          kind: WebButtonKind.danger,
          expand: true,
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
      ],
    );

    return WebPage(
      title: 'Store profile',
      subtitle: 'How your canteen appears to customers.',
      actions: [
        WebButton(
          label: 'Edit store details',
          icon: Icons.edit_outlined,
          onPressed: () => context.push('/vendor/profile/edit'),
        ),
      ],
      children: [
        WebSplit(
          sideWidth: 340,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [front, const SizedBox(height: 22), info],
          ),
          side: account,
        ),
      ],
    );
  }
}
