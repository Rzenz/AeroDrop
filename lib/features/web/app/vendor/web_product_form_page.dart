import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/product_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../../../dashboard/widgets/dash_kit.dart';
import '../web_kit.dart';

/// Adding or editing a product, with the card customers will see updating
/// beside the form as it is filled in. The same fields, rules, upload and
/// save calls as the app's listing screen.
class WebProductFormPage extends ConsumerStatefulWidget {
  const WebProductFormPage({super.key, this.productId});

  /// Null to add a product.
  final String? productId;

  @override
  ConsumerState<WebProductFormPage> createState() => _WebProductFormPageState();
}

class _WebProductFormPageState extends ConsumerState<WebProductFormPage> {
  static const _categories = [
    'Food',
    'Drinks',
    'Snacks',
    'Electronics',
    'Stationery',
    'Books',
    'Reviewers',
    'Maritime Supplies',
    'Equipment',
  ];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _weight = TextEditingController();
  String _category = 'Food';
  bool _available = true;
  bool _saving = false;
  bool _uploading = false;
  String _imageUrl = '';

  bool get _edit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _price, _stock, _weight]) {
      c.addListener(() => setState(() {}));
    }
    if (_edit) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    var p = ref
        .read(vendorProductsProvider)
        .products
        .where((p) => p.id == widget.productId)
        .firstOrNull;
    if (p == null && SupabaseService.isConfigured) {
      try {
        final r = await SupabaseService.client
            .from('products')
            .select()
            .eq('id', widget.productId!)
            .maybeSingle();
        if (r != null) {
          p = ProductModel(
            id: r['id'].toString(),
            vendorId: r['vendor_id'].toString(),
            vendorName: '',
            name: r['name'].toString(),
            description: r['description']?.toString() ?? '',
            price: (r['price'] as num?)?.toDouble() ?? 0.0,
            stock: (r['stock_quantity'] as num?)?.toInt() ?? 0,
            category: r['category']?.toString() ?? 'Food',
            weightKg: ((r['weight_grams'] as num?) ?? 0) / 1000.0,
            imageUrl: r['image_url']?.toString() ?? '',
            isAvailable: r['is_active'] as bool? ?? true,
          );
        }
      } catch (_) {}
    }
    if (p == null || !mounted) return;
    setState(() {
      _name.text = p!.name;
      _description.text = p.description;
      _price.text = p.price.toString();
      _stock.text = p.stock.toString();
      _weight.text = (p.weightKg * 1000).toStringAsFixed(0);
      _category = p.category;
      _available = p.isAvailable;
      _imageUrl = p.imageUrl;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _stock, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go('/vendor/products');

  Future<void> _pickImage() async {
    try {
      final image = await ImageUtils.pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
        title: 'Adjust product image',
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
      final bytes = await image.readAsBytes();
      final userId =
          ref.read(authProvider).user?.id ??
          SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      setState(() => _uploading = true);
      final file =
          '$userId/prod_${DateTime.now().millisecondsSinceEpoch}${check.fileExtension ?? '.png'}';
      final bucket = SupabaseService.client.storage.from('product-images');
      await bucket.uploadBinary(
        file,
        bytes,
        fileOptions: FileOptions(contentType: check.mimeType, upsert: true),
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = bucket.getPublicUrl(file);
        _uploading = false;
      });
      showNeuSnack(context, 'Photo uploaded.', tone: NeuToneKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showNeuSnack(
        context,
        'The photo could not be uploaded: $e',
        tone: NeuToneKind.error,
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final n = ref.read(vendorProductsProvider.notifier);
    final price = double.tryParse(_price.text) ?? 0.0;
    final stock = int.tryParse(_stock.text) ?? 0;
    final kg = (double.tryParse(_weight.text) ?? 0.0) / 1000.0;
    final ok = _edit
        ? await n.editProduct(
            id: widget.productId!,
            name: _name.text,
            description: _description.text,
            price: price,
            stock: stock,
            categoryName: _category,
            weightKg: kg,
            imageUrl: _imageUrl.trim(),
            isAvailable: _available,
          )
        : await n.addProduct(
            name: _name.text,
            description: _description.text,
            price: price,
            stock: stock,
            categoryName: _category,
            weightKg: kg,
            imageUrl: _imageUrl.trim(),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    showNeuSnack(
      context,
      ok
          ? (_edit ? 'Product saved.' : 'Product added to your menu.')
          : (_edit
                ? 'The product could not be saved.'
                : 'The product could not be added.'),
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
    if (ok) _back();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  String? _number(String? v, {bool whole = false}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = whole ? int.tryParse(v.trim()) : double.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final grams = int.tryParse(_weight.text.trim()) ?? 0;

    Widget pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 520
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

    final details = WebPanel(
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebField(
            label: 'Name',
            controller: _name,
            hint: 'Chicken adobo rice bowl',
            validator: _required,
          ),
          const SizedBox(height: 16),
          WebField(
            label: 'Description',
            controller: _description,
            hint: 'What is in it, and how big a serving is.',
            maxLines: 4,
            validator: _required,
          ),
          const SizedBox(height: 18),
          Text(
            'Category',
            style: WebText.label(size: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          WebChips(
            labels: _categories,
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
        ],
      ),
    );

    final pricing = WebPanel(
      title: 'Price, stock and weight',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pair(
            WebField(
              label: 'Price (₱)',
              controller: _price,
              hint: '85.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _number,
            ),
            WebField(
              label: 'In stock',
              controller: _stock,
              hint: '20',
              keyboardType: TextInputType.number,
              validator: (v) => _number(v, whole: true),
            ),
          ),
          const SizedBox(height: 16),
          WebField(
            label: 'Weight (grams)',
            controller: _weight,
            hint: '350',
            keyboardType: TextInputType.number,
            helper: grams > 500
                ? 'Heavier than one drone can lift (500 g) — it can never be '
                      'delivered on its own.'
                : 'The drone lifts 500 g per order, so customers see this '
                      'when they fill their cart.',
            validator: (v) => _number(v, whole: true),
          ),
          if (_edit) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Listed on your menu',
                        style: WebText.label(size: 14.5),
                      ),
                      Text(
                        'Off hides it from customers without deleting it.',
                        style: WebText.body(size: 12.5),
                      ),
                    ],
                  ),
                ),
                WebTabs(
                  labels: const ['Listed', 'Hidden'],
                  selected: _available ? 0 : 1,
                  onSelected: (i) => setState(() => _available = i == 0),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final photo = WebPanel(
      title: 'Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebWell(
            padding: const EdgeInsets.all(8),
            radius: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _uploading
                    ? const Center(child: CircularProgressIndicator())
                    : (_imageUrl.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 34,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No photo yet',
                                    style: WebText.body(size: 13),
                                  ),
                                ],
                              ),
                            )
                          : Image.network(_imageUrl, fit: BoxFit.cover)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          WebButton(
            label: _imageUrl.isEmpty ? 'Upload a photo' : 'Replace photo',
            icon: Icons.upload_rounded,
            kind: WebButtonKind.secondary,
            expand: true,
            onPressed: _uploading ? null : _pickImage,
          ),
          if (_imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            WebButton(
              label: 'Remove photo',
              kind: WebButtonKind.ghost,
              expand: true,
              onPressed: () => setState(() => _imageUrl = ''),
            ),
          ],
        ],
      ),
    );

    // How the card will look in the shop, from what is typed so far.
    final preview = WebPanel(
      title: 'Preview',
      subtitle: 'How customers see it in the shop.',
      child: Center(
        child: SizedBox(
          width: 230,
          child: IgnorePointer(
            child: DashProductCard(
              product: ProductModel(
                id: 'preview',
                vendorId: user?.id ?? '',
                vendorName: user?.businessName ?? 'Your store',
                name: _name.text.isEmpty ? 'Product name' : _name.text,
                description: _description.text,
                price: double.tryParse(_price.text) ?? 0,
                // Until a stock figure is typed, show the card as it will look
                // in stock rather than sold out.
                stock: int.tryParse(_stock.text) ?? 1,
                category: _category,
                weightKg: grams / 1000,
                imageUrl: _imageUrl,
                isAvailable: _available,
              ),
              inCart: 0,
              onOpen: () {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    return WebPage(
      title: _edit ? 'Edit product' : 'Add a product',
      subtitle: _edit ? null : 'It goes on your menu as soon as you save.',
      back: true,
      onBack: _back,
      maxWidth: 1180,
      actions: [
        WebButton(
          label: 'Cancel',
          kind: WebButtonKind.secondary,
          onPressed: _saving ? null : _back,
        ),
        WebButton(
          label: _edit ? 'Save changes' : 'Add product',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _uploading ? null : _save,
        ),
      ],
      children: [
        Form(
          key: _form,
          child: WebSplit(
            sideWidth: 340,
            main: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 22), pricing],
            ),
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [photo, const SizedBox(height: 22), preview],
            ),
          ),
        ),
      ],
    );
  }
}
