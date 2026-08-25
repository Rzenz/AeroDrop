import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../mock_data/products_mock.dart';
import '../../core/providers/product_provider.dart';
import '../../core/services/supabase_service.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId; // null = add, non-null = edit
  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _description, _price, _stock, _weight;
  String _category = 'Food';
  bool _available = true;
  bool _saving = false;
  String _imageUrl = '';

  bool get _isEdit => widget.productId != null;

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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
    _price = TextEditingController();
    _stock = TextEditingController();
    _weight = TextEditingController();

    // In edit mode, load state after first build when ref is available
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var product = ref
            .read(vendorProductsProvider)
            .products
            .where((p) => p.id == widget.productId)
            .firstOrNull;

        if (product == null && SupabaseService.isConfigured) {
          try {
            final res = await SupabaseService.client
                .from('products')
                .select()
                .eq('id', widget.productId!)
                .maybeSingle();
            if (res != null) {
              final cat = res['category']?.toString() ?? 'Food';
              product = MockProduct(
                id: res['id'].toString(),
                vendorId: res['vendor_id'].toString(),
                vendorName: '',
                name: res['name'].toString(),
                description: res['description']?.toString() ?? '',
                price: (res['price'] as num?)?.toDouble() ?? 0.0,
                stock: (res['stock_quantity'] as num?)?.toInt() ?? 0,
                category: cat,
                weightKg: (((res['weight_grams'] as num?) ?? 0) / 1000.0),
                imageUrl: res['image_url']?.toString() ?? '',
                isAvailable: res['is_active'] as bool? ?? true,
              );
            }
          } catch (_) {}
        }

        if (product != null && mounted) {
          setState(() {
            _name.text = product!.name;
            _description.text = product.description;
            _price.text = product.price.toString();
            _stock.text = product.stock.toString();
            _weight.text = (product.weightKg * 1000).toStringAsFixed(0);
            _category = product.category;
            _available = product.isAvailable;
            _imageUrl = product.imageUrl;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEdit ? 'Modify Listing' : 'New Product Listing',
          style: AppTextStyles.subHead(fontSize: 18, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Showcase Image Placeholder
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: _imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: AppColors.accent,
                              size: 32,
                            ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.accent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Upload Product Showcase Image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supports PNG, JPG up to 5MB',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),

            _Field(
              controller: _name,
              label: 'Product Name',
              hint: 'e.g. Chicken Adobo Rice Meal',
              validator: (v) => v!.isEmpty ? 'Item name is required' : null,
            ),
            const SizedBox(height: 18),

            _Field(
              controller: _description,
              label: 'Product Description',
              hint: 'Describe ingredients, preparation time, etc…',
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Description is required' : null,
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _price,
                    label: 'Price (₱)',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _stock,
                    label: 'Stock Allocation',
                    hint: 'e.g. 50',
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _Field(
              controller: _weight,
              label: 'Weight (grams)',
              hint: 'e.g. 350',
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty
                  ? 'Weight is required for drone cargo limits'
                  : null,
            ),
            const SizedBox(height: 18),

            // Segment Tag Chip List
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Segment',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final isSelected = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryDark
                                : Colors.white,
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 20),

            // Product Availability toggle card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_add_check_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available for Orders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _available
                              ? 'Visible to students on campus'
                              : 'Hidden from campus store catalog',
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _available,
                    activeThumbColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
                    inactiveThumbColor: AppColors.textSecondaryDark,
                    inactiveTrackColor: Colors.white10,
                    onChanged: (value) => setState(() => _available = value),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 32),

            // Save listings button
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryDark,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Apply Changes' : 'Publish Listing',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
            ).animate().fadeIn(delay: 160.ms),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    final name = _name.text;
    final description = _description.text;
    final price = double.tryParse(_price.text) ?? 0.0;
    final stock = int.tryParse(_stock.text) ?? 0;
    final weightGrams = double.tryParse(_weight.text) ?? 0.0;
    final weightKg = weightGrams / 1000.0;
    final imgUrl = _imageUrl.isNotEmpty
        ? _imageUrl
        : 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400';

    bool success;
    if (_isEdit) {
      success = await ref
          .read(vendorProductsProvider.notifier)
          .editProduct(
            id: widget.productId!,
            name: name,
            description: description,
            price: price,
            stock: stock,
            categoryName: _category,
            weightKg: weightKg,
            imageUrl: imgUrl,
            isAvailable: _available,
          );
    } else {
      success = await ref
          .read(vendorProductsProvider.notifier)
          .addProduct(
            name: name,
            description: description,
            price: price,
            stock: stock,
            categoryName: _category,
            weightKg: weightKg,
            imageUrl: imgUrl,
          );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Product updated successfully.'
                : 'Product added successfully.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Failed to update product.' : 'Failed to add product.',
          ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body(
            fontSize: 12,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
