import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class VendorViewModel {
  final String id;
  final String ownerName;
  final String businessName;
  final String? businessCategory;
  final String? businessDescription;
  final String phoneNumber;
  final String email;
  final String? avatarUrl;
  final String? campusLocationId;

  // UI compatibility helpers
  final String building;
  final Color logoColor;
  final String logoInitials;
  final bool isOpen;
  final bool isActive;
  final List<String> categories;
  final double rating;
  final int totalOrders;

  String get phone => phoneNumber;
  String get description => businessDescription ?? '';

  const VendorViewModel({
    required this.id,
    required this.ownerName,
    required this.businessName,
    this.businessCategory,
    this.businessDescription,
    required this.phoneNumber,
    required this.email,
    this.avatarUrl,
    this.campusLocationId,
    required this.building,
    this.logoColor = const Color(0xFFFF6B35),
    required this.logoInitials,
    this.isOpen = true,
    this.isActive = true,
    this.categories = const ['Food', 'Drinks', 'Snacks'],
    this.rating = 4.5,
    this.totalOrders = 0,
  });

  factory VendorViewModel.fromMap(Map<String, dynamic> v) {
    final bizName = v['business_name']?.toString() ?? 'Vendor';
    final initials = bizName.length >= 2
        ? bizName.substring(0, 2).toUpperCase()
        : (bizName.isNotEmpty ? bizName.substring(0, 1).toUpperCase() : 'V');

    final locName =
        (v['campus_locations'] as Map<String, dynamic>?)?['name']?.toString() ??
        'UCLM Campus';

    return VendorViewModel(
      id: v['id'].toString(),
      ownerName: v['full_name']?.toString() ?? 'Vendor',
      businessName: bizName,
      businessCategory: v['business_category']?.toString(),
      businessDescription: v['business_description']?.toString(),
      phoneNumber: v['phone_number']?.toString() ?? '',
      email: v['email']?.toString() ?? '',
      avatarUrl: v['avatar_url']?.toString(),
      campusLocationId: v['campus_location_id']?.toString(),
      building: locName,
      logoInitials: initials,
    );
  }
}

class VendorState {
  final List<VendorViewModel> vendors;
  final bool isLoading;
  final String? errorMessage;

  VendorState({
    required this.vendors,
    this.isLoading = false,
    this.errorMessage,
  });

  factory VendorState.empty() => VendorState(vendors: []);
}

class VendorNotifier extends StateNotifier<VendorState> {
  VendorNotifier() : super(VendorState.empty()) {
    loadVendors();
  }

  final _client = SupabaseService.client;

  Future<void> loadVendors() async {
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      state = VendorState(vendors: []);
      return;
    }

    state = VendorState(vendors: state.vendors, isLoading: true);
    try {
      if (!SupabaseService.isConfigured) {
        if (mounted) {
          state = VendorState(vendors: [], isLoading: false);
        }
        return;
      }

      // Only show fully approved and active vendors.
      final vendorsRes = await _client
          .from('users')
          .select('*, campus_locations(name)')
          .eq('role', 'vendor')
          .eq('vendor_status', 'active')
          .eq('account_status', 'active');

      if (!mounted) return;

      final List<VendorViewModel> loaded = [];
      for (final v in vendorsRes) {
        loaded.add(VendorViewModel.fromMap(v));
      }

      state = VendorState(vendors: loaded, isLoading: false);
    } catch (e) {
      debugPrint('Load vendors failed: $e');
      if (mounted) {
        state = VendorState(
          vendors: [],
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }
}

final vendorProvider = StateNotifierProvider<VendorNotifier, VendorState>(
  (_) => VendorNotifier(),
);
