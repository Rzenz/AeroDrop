import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_model.dart';
import '../models/order_quote_model.dart';
import '../services/supabase_service.dart';
import 'weather_provider.dart';

/// What to price: one vendor's items delivered to one drop-off.
///
/// [items] is a canonical "productId×quantity" string rather than a list, so
/// two requests for the same cart compare equal and share one quote.
typedef OrderQuoteRequest = ({
  String vendorId,
  String dropoffLocationId,
  String items,
});

/// The request for [cart] going to [dropoffLocationId], or null when there is
/// nothing to price yet.
OrderQuoteRequest? orderQuoteRequestFor(
  List<CartItem> cart,
  String? dropoffLocationId,
) {
  if (cart.isEmpty || dropoffLocationId == null || dropoffLocationId.isEmpty) {
    return null;
  }
  final items = [for (final i in cart) '${i.productId}×${i.quantity}']..sort();
  return (
    vendorId: cart.first.vendorId,
    dropoffLocationId: dropoffLocationId,
    items: items.join(','),
  );
}

/// The `p_items` payload for quote_order_fee: only what pricing reads.
List<Map<String, dynamic>> quoteItemsPayload(String items) => [
  for (final entry in items.split(','))
    if (entry.contains('×'))
      {
        'product_id': entry.substring(0, entry.lastIndexOf('×')),
        'quantity': int.parse(entry.substring(entry.lastIndexOf('×') + 1)),
      },
];

/// The server's price for an order, from quote_order_fee(): the same function
/// place_order charges with. There is no local fallback; when the quote fails
/// the checkout says so instead of showing a figure nobody will charge.
///
/// Re-quotes when the weather moves in or out of caution, because the server
/// adds its surcharge then.
final orderQuoteProvider = FutureProvider.autoDispose
    .family<OrderQuote, OrderQuoteRequest>((ref, request) async {
      ref.watch(weatherProvider.select((w) => w.safetyStatus == 'caution'));

      if (!SupabaseService.isConfigured) {
        throw StateError('Delivery pricing is unavailable offline.');
      }

      try {
        final res = await SupabaseService.client.rpc(
          'quote_order_fee',
          params: {
            'p_vendor_id': request.vendorId,
            'p_delivery_location_id': request.dropoffLocationId,
            'p_items': quoteItemsPayload(request.items),
          },
        );
        if (res is! Map) throw const FormatException('Unexpected quote reply');
        return OrderQuote.fromMap(Map<String, dynamic>.from(res));
      } on PostgrestException catch (e) {
        // The server's own sentence, not the exception's debug dump
        throw StateError(e.message);
      }
    });
