import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock_data/products_mock.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

class ProductState {
  final List<MockProduct> products;
  final List<String> categories;
  final bool isLoading;
  final String? errorMessage;

  ProductState({
    required this.products,
    required this.categories,
    this.isLoading = false,
    this.errorMessage,
  });

  factory ProductState.empty() =>
      ProductState(products: [], categories: ['All']);
}

// ── All-vendor product list (student marketplace) ─────────────────────────────

class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier() : super(ProductState.empty()) {
    loadProducts();
  }

  final _client = SupabaseService.client;

  Future<void> loadProducts() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      state = ProductState(products: [], categories: ['All']);
      return;
    }

    state = ProductState(
      products: state.products,
      categories: state.categories,
      isLoading: true,
    );
    try {
      if (!SupabaseService.isConfigured) {
        if (mounted) {
          state = ProductState(
            products: [],
            categories: ['All'],
            isLoading: false,
          );
        }
        return;
      }

      List<dynamic> productsRes;
      try {
        productsRes = await _client
            .from('products')
            .select(
              '*, users!vendor_id(full_name, business_name, role, vendor_status, account_status)',
            )
            .eq('is_active', true)
            .order('created_at', ascending: false);
      } catch (err) {
        debugPrint('Fallback select on products without relation hint: $err');
        productsRes = await _client
            .from('products')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false);
      }

      if (!mounted) return;

      final List<MockProduct> loaded = [];
      final Set<String> catSet = {};
      for (final p in productsRes) {
        final vendorMap = p['users'] as Map<String, dynamic>?;
        if (vendorMap != null) {
          final role = vendorMap['role']?.toString().toLowerCase();
          final vendorStatus =
              vendorMap['vendor_status']?.toString().toLowerCase();
          final accountStatus =
              vendorMap['account_status']?.toString().toLowerCase();

          if (accountStatus == 'suspended' ||
              accountStatus == 'deleted' ||
              vendorStatus == 'rejected' ||
              vendorStatus == 'suspended') {
            continue;
          }
          if (role != null && role != 'vendor') {
            continue;
          }
        }

        final vendorName =
            vendorMap?['business_name']?.toString() ??
            vendorMap?['full_name']?.toString() ??
            p['vendor_name']?.toString() ??
            'Campus Vendor';
        final cat = p['category']?.toString() ?? 'Other';
        catSet.add(cat);
        loaded.add(
          MockProduct(
            id: p['id'].toString(),
            vendorId: p['vendor_id']?.toString() ?? '',
            vendorName: vendorName,
            name: p['name']?.toString() ?? 'Item',
            description: p['description']?.toString() ?? '',
            price: (p['price'] as num?)?.toDouble() ?? 0.0,
            stock: (p['stock_quantity'] as num?)?.toInt() ?? 0,
            category: cat,
            weightKg: (((p['weight_grams'] as num?) ?? 0) / 1000.0),
            imageUrl:
                p['image_url']?.toString().isNotEmpty == true
                    ? p['image_url'].toString()
                    : 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400',
            isAvailable: p['is_active'] as bool? ?? true,
          ),
        );
      }

      final categories = ['All', ...catSet.toList()..sort()];
      state = ProductState(
        products: loaded,
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Load products failed: $e');
      if (mounted) {
        state = ProductState(
          products: [],
          categories: ['All'],
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }
}

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>(
  (_) => ProductNotifier(),
);

// ── Current vendor info (from public.users) ───────────────────────────────────

final currentVendorProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final user = ref.watch(authProvider).user;
  if (user == null || !user.isVendor) return null;
  if (!SupabaseService.isConfigured) return null;

  final res = await SupabaseService.client
      .from('users')
      .select('*, campus_locations(name)')
      .eq('id', user.id)
      .maybeSingle();

  return res;
});

// ── Vendor's own product list ─────────────────────────────────────────────────

class VendorProductsNotifier extends StateNotifier<ProductState> {
  final Ref ref;
  VendorProductsNotifier(this.ref) : super(ProductState.empty()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      state = ProductState(products: [], categories: ['All']);
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = ProductState(
      products: state.products,
      categories: state.categories,
      isLoading: true,
    );

    try {
      if (!SupabaseService.isConfigured) {
        if (mounted) {
          state = ProductState(
            products: [],
            categories: ['All'],
            isLoading: false,
          );
        }
        return;
      }

      // Use auth user UUID directly as vendor_id — no vendors table needed.
      final productsRes = await SupabaseService.client
          .from('products')
          .select()
          .eq('vendor_id', user.id);

      if (!mounted) return;

      final List<MockProduct> loaded = [];
      final Set<String> catSet = {};
      for (final p in productsRes) {
        final cat = p['category']?.toString() ?? 'Other';
        catSet.add(cat);
        loaded.add(
          MockProduct(
            id: p['id'].toString(),
            vendorId: p['vendor_id'].toString(),
            vendorName: user.businessName ?? user.fullName,
            name: p['name'].toString(),
            description: p['description']?.toString() ?? '',
            price: (p['price'] as num?)?.toDouble() ?? 0.0,
            stock: (p['stock_quantity'] as num?)?.toInt() ?? 0,
            category: cat,
            weightKg: (((p['weight_grams'] as num?) ?? 0) / 1000.0),
            imageUrl: p['image_url']?.toString() ?? '',
            isAvailable: p['is_active'] as bool? ?? true,
          ),
        );
      }

      state = ProductState(
        products: loaded,
        categories: ['All', ...catSet.toList()..sort()],
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Load vendor products failed: $e');
      if (mounted) {
        state = ProductState(
          products: [],
          categories: ['All'],
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<bool> addProduct({
    required String name,
    required String description,
    required double price,
    required int stock,
    required String categoryName,
    required double weightKg,
    required String imageUrl,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null) return false;

    try {
      await SupabaseService.client.from('products').insert({
        'vendor_id': user.id, // direct UUID, no vendors table lookup
        'name': name,
        'description': description,
        'price': price,
        'stock_quantity': stock,
        'category': categoryName,
        'weight_grams': (weightKg * 1000).toInt(),
        'image_url': imageUrl,
        'is_active': true,
      });

      if (!mounted) return false;

      await loadProducts();
      ref.read(productProvider.notifier).loadProducts();
      return true;
    } catch (e) {
      debugPrint('Add product failed: $e');
      return false;
    }
  }

  Future<bool> editProduct({
    required String id,
    required String name,
    required String description,
    required double price,
    required int stock,
    required String categoryName,
    required double weightKg,
    required String imageUrl,
    required bool isAvailable,
  }) async {
    try {
      await SupabaseService.client
          .from('products')
          .update({
            'name': name,
            'description': description,
            'price': price,
            'stock_quantity': stock,
            'category': categoryName,
            'weight_grams': (weightKg * 1000).toInt(),
            'image_url': imageUrl,
            'is_active': isAvailable,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return false;

      await loadProducts();
      ref.read(productProvider.notifier).loadProducts();
      return true;
    } catch (e) {
      debugPrint('Edit product failed: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await SupabaseService.client.from('products').delete().eq('id', id);

      if (!mounted) return false;

      await loadProducts();
      ref.read(productProvider.notifier).loadProducts();
      return true;
    } catch (e) {
      debugPrint('Delete product failed: $e');
      return false;
    }
  }
}

final vendorProductsProvider =
    StateNotifierProvider<VendorProductsNotifier, ProductState>((ref) {
      return VendorProductsNotifier(ref);
    });
