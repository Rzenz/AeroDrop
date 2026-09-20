import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/product_model.dart';
import 'package:aerodrop/core/providers/vendor_provider.dart';
import 'package:aerodrop/core/providers/order_provider.dart';

void main() {
  group('1. Customer Shop & Vendor Stores Tests', () {
    test('VendorViewModel handles ratings and review count consistently', () {
      // Vendor with reviews
      final v1 = VendorViewModel(
        id: 'v1',
        ownerName: 'Vendor One',
        businessName: 'Cafe Aero',
        phoneNumber: '09123456789',
        email: 'cafe@aero.com',
        building: 'Building A',
        logoInitials: 'CA',
        rating: 4.8,
        reviewCount: 12,
      );

      expect(v1.hasReviews, isTrue);
      expect(v1.shortRatingDisplay, '4.8');
      expect(v1.ratingDisplay, '4.8');
      expect(v1.ratingLabel, '4.8 (12 reviews)');

      // Single review
      final vSingle = VendorViewModel(
        id: 'v-single',
        ownerName: 'Vendor Single',
        businessName: 'Boba Spot',
        phoneNumber: '09123456788',
        email: 'boba@aero.com',
        building: 'Building B',
        logoInitials: 'BS',
        rating: 5.0,
        reviewCount: 1,
      );
      expect(vSingle.hasReviews, isTrue);
      expect(vSingle.shortRatingDisplay, '5.0');
      expect(vSingle.ratingLabel, '5.0 (1 review)');

      // Vendor with no reviews (must show 'New' or 'No reviews yet', never '0.0')
      final vNew = VendorViewModel(
        id: 'v-new',
        ownerName: 'Vendor New',
        businessName: 'New Bakery',
        phoneNumber: '09123456787',
        email: 'bakery@aero.com',
        building: 'Building C',
        logoInitials: 'NB',
        rating: 0.0,
        reviewCount: 0,
      );
      expect(vNew.hasReviews, isFalse);
      expect(vNew.shortRatingDisplay, 'New');
      expect(vNew.ratingDisplay, 'No reviews yet');
      expect(vNew.ratingLabel, 'No reviews yet');
    });

    test('ProductModel handles ratings and review count consistently', () {
      // Product with reviews
      const p1 = ProductModel(
        id: 'p1',
        vendorId: 'v1',
        vendorName: 'Cafe Aero',
        name: 'Latte',
        description: 'Fresh coffee',
        price: 120.0,
        stock: 10,
        category: 'Drinks',
        weightKg: 0.3,
        imageUrl: '',
        isAvailable: true,
        rating: 4.5,
        reviewCount: 8,
      );
      expect(p1.hasReviews, isTrue);
      expect(p1.shortRatingDisplay, '4.5');
      expect(p1.ratingLabel, '4.5 (8 reviews)');

      // Product with 1 review
      const pSingle = ProductModel(
        id: 'p-single',
        vendorId: 'v1',
        vendorName: 'Cafe Aero',
        name: 'Croissant',
        description: 'Warm pastry',
        price: 85.0,
        stock: 5,
        category: 'Food',
        weightKg: 0.15,
        imageUrl: '',
        isAvailable: true,
        rating: 5.0,
        reviewCount: 1,
      );
      expect(pSingle.hasReviews, isTrue);
      expect(pSingle.shortRatingDisplay, '5.0');
      expect(pSingle.ratingLabel, '5.0 (1 review)');

      // Product with no reviews (never '0.0')
      const pNew = ProductModel(
        id: 'p-new',
        vendorId: 'v1',
        vendorName: 'Cafe Aero',
        name: 'Iced Matcha',
        description: 'Green tea latte',
        price: 140.0,
        stock: 15,
        category: 'Drinks',
        weightKg: 0.35,
        imageUrl: '',
        isAvailable: true,
        rating: 0.0,
        reviewCount: 0,
      );
      expect(pNew.hasReviews, isFalse);
      expect(pNew.shortRatingDisplay, 'New');
      expect(pNew.ratingLabel, 'No reviews yet');
    });
  });

  group('2. Nav Badge Counts Tests', () {
    test('customerActiveOrdersCountProvider counts active order statuses', () {
      final container = ProviderContainer(
        overrides: [
          orderProvider.overrideWith((ref) => _FakeOrderNotifier([
            OrderModel(
              id: 'ord-1',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'pending',
              dropoffLocationId: 'loc1',
              totalAmount: 150,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-2',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'confirmed',
              dropoffLocationId: 'loc1',
              totalAmount: 200,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-3',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'preparing',
              dropoffLocationId: 'loc1',
              totalAmount: 180,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-4',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'ready_for_delivery',
              dropoffLocationId: 'loc1',
              totalAmount: 220,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-5',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'in_transit',
              dropoffLocationId: 'loc1',
              totalAmount: 300,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-6',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'delivered',
              dropoffLocationId: 'loc1',
              totalAmount: 120,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'ord-7',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'cancelled',
              dropoffLocationId: 'loc1',
              totalAmount: 100,
              createdAt: DateTime.now(),
              items: [],
            ),
          ])),
        ],
      );

      final count = container.read(customerActiveOrdersCountProvider);
      // ord-1..5 are active; ord-6 (delivered) and ord-7 (cancelled) are not.
      expect(count, 5);
    });

    test('vendorActionOrdersCountProvider counts orders needing vendor action', () {
      final container = ProviderContainer(
        overrides: [
          vendorOrdersProvider.overrideWith((ref) => _FakeOrderNotifier([
            OrderModel(
              id: 'vord-1',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'pending',
              dropoffLocationId: 'loc1',
              totalAmount: 150,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'vord-2',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'confirmed',
              dropoffLocationId: 'loc1',
              totalAmount: 200,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'vord-3',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'preparing',
              dropoffLocationId: 'loc1',
              totalAmount: 180,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'vord-4',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'ready_for_delivery', // already ready, vendor acted
              dropoffLocationId: 'loc1',
              totalAmount: 220,
              createdAt: DateTime.now(),
              items: [],
            ),
            OrderModel(
              id: 'vord-5',
              userId: 'u1',
              vendorId: 'v1',
              orderStatus: 'delivered',
              dropoffLocationId: 'loc1',
              totalAmount: 120,
              createdAt: DateTime.now(),
              items: [],
            ),
          ])),
        ],
      );

      final count = container.read(vendorActionOrdersCountProvider);
      // pending + confirmed + preparing = 3
      expect(count, 3);
    });
  });

  group('3. Admin Deliveries Cancelled Orders with No Delivery Tests', () {
    test('DeliveryModel supports noDroneDispatched and cancellation reason mapping', () {
      final d = DeliveryModel(
        id: 'ord-cancelled-1',
        orderId: 'ord-cancelled-1',
        senderName: 'Campus Coffee',
        recipientName: 'Erickson',
        recipientPhone: '09123456789',
        deliveryAddress: 'Maritime Building 3F',
        packageName: 'Iced Coffee (x2)',
        packageWeight: 0.4,
        packageType: 'Food',
        status: DeliveryStatus.cancelled,
        noDroneDispatched: true,
        cancellationReason: 'weather_grounded',
        eta: 'N/A',
        createdAt: DateTime.now(),
        progress: 0.0,
      );

      expect(d.status, DeliveryStatus.cancelled);
      expect(d.noDroneDispatched, isTrue);
      expect(d.droneId, isNull);
      expect(d.cancellationReasonDisplay, 'Weather Grounded');

      // Test vendor cancellation
      final dVendor = d.copyWith(cancellationReason: 'vendor');
      expect(dVendor.cancellationReasonDisplay, 'Cancelled by Vendor');

      // Test customer cancellation
      final dCustomer = d.copyWith(cancellationReason: 'customer');
      expect(dCustomer.cancellationReasonDisplay, 'Cancelled by Customer');
    });
  });
}

class _FakeOrderNotifier extends StateNotifier<OrderState> implements OrderNotifier, VendorOrdersNotifier {
  _FakeOrderNotifier(List<OrderModel> orders) : super(OrderState(orders: orders));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
