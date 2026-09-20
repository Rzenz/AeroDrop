import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerodrop/core/utils/card_validator.dart';
import 'package:aerodrop/core/models/review_model.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/core/models/delivery_model.dart';
import 'package:aerodrop/core/providers/delivery_provider.dart';

void main() {
  group('Payment Validation & Card Simulation Tests', () {
    test('CardValidator validates Luhn algorithm accurately', () {
      // Valid Luhn card numbers (test card patterns)
      expect(CardValidator.isValidLuhn('4532015112830366'), isTrue); // Visa
      expect(CardValidator.isValidLuhn('5425233430109903'), isTrue); // Mastercard
      expect(CardValidator.isValidLuhn('378282246310005'), isTrue);  // Amex

      // Invalid Luhn
      expect(CardValidator.isValidLuhn('4532015112830367'), isFalse);
      expect(CardValidator.isValidLuhn('4000000000000001'), isFalse);
      expect(CardValidator.isValidLuhn(''), isFalse);
      expect(CardValidator.isValidLuhn('abc'), isFalse);
    });

    test('CardValidator detects brand correctly', () {
      expect(CardValidator.detectBrand('4532015112830366'), 'Visa');
      expect(CardValidator.detectBrand('5425233430109903'), 'Mastercard');
      expect(CardValidator.detectBrand('378282246310005'), 'Amex');
      expect(CardValidator.detectBrand('3528000000000000'), 'JCB');
      expect(CardValidator.detectBrand('6011000000000000'), 'Discover');
      expect(CardValidator.detectBrand('9999000000000000'), 'Card');
    });

    test('CardValidator validates expiry dates correctly', () {
      // Valid future dates
      expect(CardValidator.isValidExpiry('12/35'), isTrue);
      expect(CardValidator.isValidExpiry('01/40'), isTrue);

      // Invalid dates
      expect(CardValidator.isValidExpiry('13/28'), isFalse); // Invalid month
      expect(CardValidator.isValidExpiry('00/28'), isFalse);
      expect(CardValidator.isValidExpiry('01/20'), isFalse); // Past date
      expect(CardValidator.isValidExpiry('invalid'), isFalse);
    });

    test('CardValidator validates CVV lengths correctly', () {
      expect(CardValidator.isValidCvv('123'), isTrue);
      expect(CardValidator.isValidCvv('1234'), isTrue);
      expect(CardValidator.isValidCvv('12'), isFalse);
      expect(CardValidator.isValidCvv('12345'), isFalse);
      expect(CardValidator.isValidCvv('abc'), isFalse);
    });
  });

  group('Reviews & Ratings Data Models Tests', () {
    test('RatingSummaryModel computes averages and flags correctly', () {
      const empty = RatingSummaryModel.empty;
      expect(empty.hasReviews, isFalse);
      expect(empty.displayRating, 'No reviews yet');
      expect(empty.totalReviews, 0);

      const summary = RatingSummaryModel(averageRating: 4.75, reviewCount: 8);
      expect(summary.hasReviews, isTrue);
      expect(summary.totalReviews, 8);
      expect(summary.displayRating, '4.8');
    });

    test('ReviewItemModel parses fromMap with fallback reviewer name', () {
      final item = ReviewItemModel.fromMap({
        'id': 'rev-1',
        'rating': 5,
        'comment': 'Fast and warm!',
        'created_at': '2026-09-20T10:00:00Z',
        'reviewer_name': 'Juan D.',
      });

      expect(item.id, 'rev-1');
      expect(item.rating, 5);
      expect(item.comment, 'Fast and warm!');
      expect(item.reviewerName, 'Juan D.');
    });

    test('ProductReviewInput maps to RPC payload with non-empty comment', () {
      const inputWithComment = ProductReviewInput(
        productId: 'prod-101',
        rating: 4,
        comment: 'Great drink',
      );
      final map1 = inputWithComment.toMap();
      expect(map1['product_id'], 'prod-101');
      expect(map1['rating'], 4);
      expect(map1['comment'], 'Great drink');

      const inputWithoutComment = ProductReviewInput(
        productId: 'prod-102',
        rating: 5,
        comment: '   ',
      );
      final map2 = inputWithoutComment.toMap();
      expect(map2.containsKey('comment'), isFalse);
    });
  });

  group('OrderItemModel & OrderModel Tests', () {
    test('OrderItemModel holds productId and defaults', () {
      final item = OrderItemModel(
        productId: 'p-1',
        productName: 'Iced Coffee',
        quantity: 2,
        unitPrice: 120.0,
      );
      expect(item.productId, 'p-1');
      expect(item.productName, 'Iced Coffee');
      expect(item.quantity, 2);
      expect(item.unitPrice, 120.0);
    });

    test('OrderModel.fromMap parses product_id from order_items array', () {
      final order = OrderModel.fromMap({
        'id': 'ord-999',
        'user_id': 'usr-1',
        'vendor_id': 'vnd-1',
        'order_status': 'delivered',
        'dropoff_location_id': 'loc-1',
        'total_amount': 250.0,
        'payment_method': 'card_simulated',
        'payment_status': 'paid',
        'created_at': '2026-09-20T12:00:00Z',
        'order_items': [
          {
            'product_id': 'prod-77',
            'product_name': 'Matcha Latte',
            'quantity': 1,
            'unit_price': 180.0,
          }
        ],
      });

      expect(order.id, 'ord-999');
      expect(order.paymentMethod, 'card_simulated');
      expect(order.paymentStatus, 'paid');
      expect(order.items.length, 1);
      expect(order.items.first.productId, 'prod-77');
    });
  });

  group('Admin Delivery Badge Provider Tests', () {
    DeliveryModel makeDelivery({
      required String id,
      required DeliveryStatus status,
    }) {
      return DeliveryModel(
        id: id,
        senderName: 'Vendor',
        recipientName: 'Customer',
        recipientPhone: '09123456789',
        deliveryAddress: 'Campus Pad',
        packageName: 'Meal',
        packageWeight: 0.5,
        packageType: 'Food',
        status: status,
        eta: '5 min',
        createdAt: DateTime.now(),
        progress: 0.0,
      );
    }

    test('pendingDeliveriesCountProvider reactively counts active & pending deliveries', () {
      final container = ProviderContainer(
        overrides: [
          deliveryProvider.overrideWith((ref) => _MockDeliveryNotifier([
                makeDelivery(id: 'del-1', status: DeliveryStatus.pending),
                makeDelivery(id: 'del-2', status: DeliveryStatus.inTransit),
                makeDelivery(id: 'del-3', status: DeliveryStatus.delivered),
                makeDelivery(id: 'del-4', status: DeliveryStatus.cancelled),
              ])),
        ],
      );

      final count = container.read(pendingDeliveriesCountProvider);
      // del-1 (pending) and del-2 (inTransit) = 2 active deliveries.
      // del-3 (delivered) and del-4 (cancelled) are excluded.
      expect(count, 2);
    });

    test('pendingDeliveriesCountProvider returns 0 when no active deliveries exist', () {
      final container = ProviderContainer(
        overrides: [
          deliveryProvider.overrideWith((ref) => _MockDeliveryNotifier([
                makeDelivery(id: 'del-3', status: DeliveryStatus.delivered),
              ])),
        ],
      );

      final count = container.read(pendingDeliveriesCountProvider);
      expect(count, 0);
    });
  });
}

class _MockDeliveryNotifier extends StateNotifier<List<DeliveryModel>>
    implements DeliveryNotifier {
  _MockDeliveryNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
