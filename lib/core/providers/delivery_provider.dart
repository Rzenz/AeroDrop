import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../models/delivery_model.dart';
import '../models/order_model.dart';
import 'drone_provider.dart';
import '../models/drone_model.dart';
import '../services/supabase_service.dart';
import '../services/drone_flight_calculator.dart';
import 'auth_provider.dart';
import 'order_provider.dart';
import 'weather_provider.dart';

class DeliveryNotifier extends StateNotifier<List<DeliveryModel>> {
  final Ref ref;
  // Until _loadBaseHubLocation() reads BASE-HUB; the database is the source of truth.
  (double, double) _baseHubCoords = (10.3261338, 123.9546208);
  RealtimeChannel? _deliveriesSubscription;
  RealtimeChannel? _ordersSubscription;
  RealtimeChannel? _telemetrySubscription;

  DeliveryNotifier(this.ref) : super([]) {
    _loadBaseHubLocation();
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user == null || !next.sessionUnlocked) {
        _unsubscribeRealtime();
        state = [];
      } else if (previous?.user?.id != next.user?.id ||
          previous?.sessionUnlocked != next.sessionUnlocked ||
          previous?.user?.role != next.user?.role) {
        _loadBaseHubLocation();
        _refreshDeliveriesForCurrentUser();
        refreshPendingDeliveriesCount();
        _subscribeRealtime();
      }
    });

    Future<void>.microtask(() async {
      if (mounted && SupabaseService.isConfigured) {
        _loadBaseHubLocation();
        await _refreshDeliveriesForCurrentUser();
        if (mounted) {
          _subscribeRealtime();
          refreshPendingDeliveriesCount();
        }
      }
    });
    _subscribeRealtime();
  }

  Future<bool> _checkIsAdmin() async {
    final authUser = ref.read(authProvider).user;
    if (authUser?.isAdmin ?? false) return true;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return false;
    if (currentUser.userMetadata?['role'] == 'admin') return true;
    try {
      final res = await SupabaseService.client
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();
      return res?['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshDeliveriesForCurrentUser() async {
    if (!SupabaseService.isConfigured) return;
    final isAdmin = await _checkIsAdmin();
    if (isAdmin) {
      await loadAdminDeliveriesFromSupabase();
    } else {
      await loadDeliveriesFromSupabase();
    }
  }

  Future<void> _loadBaseHubLocation() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final res = await SupabaseService.client
          .from('campus_locations')
          .select('latitude, longitude')
          .eq('location_code', 'BASE-HUB')
          .maybeSingle();
      if (res != null) {
        final lat = (res['latitude'] as num?)?.toDouble();
        final lng = (res['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _baseHubCoords = (lat, lng);
        }
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;
    _unsubscribeRealtime();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id ?? 'anon';

      // 1. Deliveries table subscription
      _deliveriesSubscription = SupabaseService.client
          .channel('deliveries_feed_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            callback: (payload) {
              if (mounted) _refreshDeliveriesForCurrentUser();
            },
          )
          .subscribe();

      // 2. Orders table subscription (for order cancellations, new orders, etc.)
      _ordersSubscription = SupabaseService.client
          .channel('orders_feed_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              if (mounted) _refreshDeliveriesForCurrentUser();
            },
          )
          .subscribe();

      // 3. Telemetry subscription
      _telemetrySubscription = SupabaseService.client
          .channel('telemetry_feed_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drone_telemetry',
            callback: (payload) {
              if (mounted) _handleRealtimeTelemetry(payload.newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to delivery realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    if (_deliveriesSubscription != null) {
      try {
        SupabaseService.client.removeChannel(_deliveriesSubscription!);
      } catch (_) {}
      _deliveriesSubscription = null;
    }
    if (_ordersSubscription != null) {
      try {
        SupabaseService.client.removeChannel(_ordersSubscription!);
      } catch (_) {}
      _ordersSubscription = null;
    }
    if (_telemetrySubscription != null) {
      try {
        SupabaseService.client.removeChannel(_telemetrySubscription!);
      } catch (_) {}
      _telemetrySubscription = null;
    }
  }

  void _handleRealtimeTelemetry(Map<String, dynamic> record) {
    final deliveryId = record['delivery_id']?.toString();
    final droneId = record['drone_id']?.toString();

    final lat = _toDoubleOrNull(record['latitude']);
    final lng = _toDoubleOrNull(record['longitude']);
    final alt = _toDoubleOrNull(record['altitude']);
    final speed = _toDoubleOrNull(record['speed']);
    final battery = _toDoubleOrNull(record['battery_level']);
    final progress = _toDoubleOrNull(record['progress']);
    final eventType = record['event_type']?.toString();

    if (battery != null) {
      try {
        ref
            .read(droneProvider.notifier)
            .updateBattery(droneId ?? 'DRN-001', battery);
      } catch (_) {}
    }

    if (lat != null && lng != null) {
      try {
        ref
            .read(droneProvider.notifier)
            .updateCoordinates(droneId ?? 'DRN-001', '$lat,$lng');
      } catch (_) {}
    }

    if (deliveryId != null) {
      state = state.map((del) {
        if (del.id == deliveryId) {
          return del.copyWith(
            currentLatitude: lat ?? del.currentLatitude,
            currentLongitude: lng ?? del.currentLongitude,
            currentAltitude: alt ?? del.currentAltitude,
            currentSpeed: speed ?? del.currentSpeed,
            batteryLevel: battery ?? del.batteryLevel,
            progress:
                (eventType == 'returning_to_base' &&
                    del.status == DeliveryStatus.delivered)
                ? del.progress
                : (progress ?? del.progress),
          );
        }
        return del;
      }).toList();
    }
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  DeliveryStatus _parseDeliveryStatus(dynamic value) {
    if (value is DeliveryStatus) return value;
    final status = value?.toString().toLowerCase() ?? '';

    switch (status) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'assigning':
        return DeliveryStatus.assigning;
      case 'intransit':
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'cancelled':
      case 'rejected':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
    }
  }

  /// LAST-RESORT fallback, for a delivery loaded without its location rows.
  /// campus_locations is the source of truth and these are copies of it that
  /// will go stale when a building moves (Maritime and the test drop-off as of
  /// migration 43).
  (double, double) _coordinatesForLocation(String? locationName) {
    if (locationName == null || locationName.isEmpty) {
      return (10.325210, 123.953201);
    }
    final query = locationName.toLowerCase();
    final coords = {
      'old building': (10.325210, 123.953201),
      'main': (10.325210, 123.953201),
      'uclm main': (10.325210, 123.953201),
      'annex 2 building': (10.325633, 123.953770),
      'annex-2': (10.325633, 123.953770),
      'annex 2': (10.325633, 123.953770),
      'basic education building': (10.325133, 123.953853),
      'basic-ed': (10.325133, 123.953853),
      'basic education': (10.325133, 123.953853),
      'basic ed': (10.325133, 123.953853),
      'maritime building': (10.3261650, 123.9543871),
      'maritime': (10.3261650, 123.9543871),
      'test drop-off point': (10.3253252, 123.9537220),
      'test drop-off': (10.3253252, 123.9537220),
      'test-drop': (10.3253252, 123.9537220),
      'base hub': _baseHubCoords,
      'base-hub': _baseHubCoords,
    };
    for (final entry in coords.entries) {
      if (query.contains(entry.key) || entry.key.contains(query)) {
        return entry.value;
      }
    }
    return (10.325210, 123.953201);
  }

  String _calculateEtaFromTimestamps(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'delivered') return '0 mins';
    if (status != 'intransit' && status != 'in_transit') {
      return data['eta']?.toString() ?? 'TBD';
    }

    final totalSecs =
        (data['estimated_delivery_seconds'] as num?)?.toDouble() ?? 60.0;
    final progress = (data['progress'] as num?)?.toDouble();
    if (progress != null && progress > 0.0) {
      final remaining = DroneFlightCalculator.calculateRemainingSeconds(
        progress: progress,
        totalDurationSeconds: totalSecs,
      );
      return DroneFlightCalculator.formatEta(remaining);
    }

    final startedAt = data['delivery_started_at'] != null
        ? DateTime.tryParse(data['delivery_started_at'].toString())
        : null;
    if (startedAt == null) return data['eta']?.toString() ?? 'TBD';

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = (totalSecs.round() - elapsed).clamp(0, totalSecs.round());
    return DroneFlightCalculator.formatEta(remaining);
  }

  DeliveryModel _mapToDeliveryModel(Map<String, dynamic> data) {
    final order = data['orders'] != null
        ? Map<String, dynamic>.from(data['orders'])
        : {};

    // Customer/Recipient
    final customer = order['customer'] != null
        ? Map<String, dynamic>.from(order['customer'])
        : {};
    final recipientName =
        customer['full_name']?.toString() ?? 'Unknown Recipient';
    final recipientPhone = customer['phone_number']?.toString() ?? '';

    // Vendor/Sender
    final vendor = order['vendor'] != null
        ? Map<String, dynamic>.from(order['vendor'])
        : {};
    final senderName =
        vendor['business_name']?.toString() ??
        vendor['full_name']?.toString() ??
        'Unknown Vendor';

    // Dropoff location/Address
    final location = order['campus_locations'] != null
        ? Map<String, dynamic>.from(order['campus_locations'])
        : {};
    final deliveryAddress =
        location['name']?.toString() ??
        data['delivery_address']?.toString() ??
        'UCLM Campus';

    final pickupLoc = data['pickup_loc'] != null
        ? Map<String, dynamic>.from(data['pickup_loc'])
        : null;
    final dropoffLoc = data['dropoff_loc'] != null
        ? Map<String, dynamic>.from(data['dropoff_loc'])
        : null;

    final pickupLocationId =
        data['pickup_location_id']?.toString() ?? pickupLoc?['id']?.toString();
    final dropoffLocationId =
        data['dropoff_location_id']?.toString() ??
        dropoffLoc?['id']?.toString();
    final pickupLocationName =
        pickupLoc?['name']?.toString() ??
        (senderName.isNotEmpty ? senderName : 'Vendor Shop');
    // A map pin instead of a building (migrations 39/40). The trigger copies
    // the coordinates onto the delivery; the label lives on the order.
    final pinLat =
        _toDoubleOrNull(data['custom_dropoff_lat']) ??
        _toDoubleOrNull(order['custom_dropoff_lat']);
    final pinLng =
        _toDoubleOrNull(data['custom_dropoff_lng']) ??
        _toDoubleOrNull(order['custom_dropoff_lng']);
    final hasPin = pinLat != null && pinLng != null;
    final rawPinLabel = order['custom_dropoff_label']?.toString().trim() ?? '';
    final pinLabel = hasPin && rawPinLabel.isNotEmpty ? rawPinLabel : null;

    final dropoffLocationName = hasPin
        ? (pinLabel ?? OrderModel.pinnedDropoffName)
        : (dropoffLoc?['name']?.toString() ?? deliveryAddress);
    // The joined rows' own coordinates, used before any lookup by name
    (double, double)? rowCoords(Map<String, dynamic>? row) {
      final lat = _toDoubleOrNull(row?['latitude']);
      final lng = _toDoubleOrNull(row?['longitude']);
      return lat != null && lng != null ? (lat, lng) : null;
    }

    final pickupLocationCoords = rowCoords(pickupLoc);
    final dropoffLocationCoords = hasPin ? null : rowCoords(dropoffLoc);

    final currentLat =
        _toDoubleOrNull(data['current_latitude']) ??
        _toDoubleOrNull(data['latitude']) ??
        _toDoubleOrNull(pickupLoc?['latitude']);
    final currentLng =
        _toDoubleOrNull(data['current_longitude']) ??
        _toDoubleOrNull(data['longitude']) ??
        _toDoubleOrNull(pickupLoc?['longitude']);
    final currentAlt =
        _toDoubleOrNull(data['current_altitude']) ??
        _toDoubleOrNull(data['altitude']);
    final currentSpd =
        _toDoubleOrNull(data['current_speed']) ??
        _toDoubleOrNull(data['speed']);
    final battLvl = _toDoubleOrNull(data['battery_level']);

    // Items / Package Details
    final items = order['order_items'] as List? ?? [];
    String packageName = 'AeroDrop Package';
    double packageWeight = 0.0;

    if (items.isNotEmpty) {
      final names = items
          .map(
            (i) =>
                '${i['product_name']?.toString() ?? ''} (x${i['quantity'] ?? 1})',
          )
          .where((n) => n.isNotEmpty)
          .toList();
      packageName = names.join(', ');
      if (packageName.isEmpty) packageName = 'AeroDrop Package';

      int totalWeightGrams = 0;
      for (final i in items) {
        final w = (i['weight_grams'] as num?)?.toInt() ?? 0;
        final q = (i['quantity'] as num?)?.toInt() ?? 1;
        totalWeightGrams += w * q;
      }
      packageWeight = totalWeightGrams / 1000.0;
    } else {
      packageName = 'No package items available.';
    }

    final status = _parseDeliveryStatus(data['status']);

    // Single authoritative source of truth: deliveries.progress
    final double rawProgress = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final progressVal = (status == DeliveryStatus.delivered)
        ? 1.0
        : rawProgress.clamp(0.0, 1.0);

    return DeliveryModel(
      id: data['id'].toString(),
      senderName: senderName,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      deliveryAddress: hasPin ? dropoffLocationName : deliveryAddress,
      customDropoffLat: hasPin ? pinLat : null,
      customDropoffLng: hasPin ? pinLng : null,
      customDropoffLabel: pinLabel,
      packageName: packageName,
      packageWeight: packageWeight,
      packageType: 'Food', // visual label
      status: status,
      droneId: data['drone_id'] != null ? 'DRN-001' : null,
      eta: _calculateEtaFromTimestamps(data),
      createdAt: _toDateTime(data['created_at']),
      progress: progressVal,
      estimatedDistanceKm: data.containsKey('estimated_distance_km')
          ? _toDoubleOrNull(data['estimated_distance_km'])
          : null,
      paymentAmount: _toDoubleOrNull(order['total_amount']),
      deliveryStartedAt: data['delivery_started_at'] != null
          ? DateTime.tryParse(data['delivery_started_at'].toString())
          : null,
      estimatedDeliverySeconds:
          (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
      deliveredAt: data['delivery_completed_at'] != null
          ? DateTime.tryParse(data['delivery_completed_at'].toString())
          : null,
      pickupLocationId: pickupLocationId,
      dropoffLocationId: dropoffLocationId,
      pickupLocationName: pickupLocationName,
      dropoffLocationName: dropoffLocationName,
      pickupLocationCoords: pickupLocationCoords,
      dropoffLocationCoords: dropoffLocationCoords,
      currentLatitude: currentLat,
      currentLongitude: currentLng,
      currentAltitude: currentAlt,
      currentSpeed: currentSpd,
      batteryLevel: battLvl,
      orderId: data['order_id']?.toString() ?? order['id']?.toString(),
      cancellationReason: order['cancellation_reason']?.toString(),
      noDroneDispatched: false,
      orderStatus: order['order_status']?.toString(),
      tripsRequired: (data['trips_required'] as num?)?.toInt() ?? 1,
      tripsCompleted: (data['trips_completed'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> loadDeliveriesFromSupabase() async {
    if (!SupabaseService.isConfigured) return;

    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      debugPrint('Load deliveries skipped: no logged in user.');
      state = [];
      return;
    }

    final isAdmin = await _checkIsAdmin();
    if (isAdmin) {
      return loadAdminDeliveriesFromSupabase();
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('''
            *,
            pickup_loc:campus_locations!pickup_location_id(id, name, latitude, longitude),
            dropoff_loc:campus_locations!dropoff_location_id(id, name, latitude, longitude),
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final authUser = ref.read(authProvider).user;
      final isAdmin = authUser?.isAdmin ?? false;
      final isVendor = authUser?.isVendor ?? false;

      final deliveries = (response as List)
          .where((item) {
            if (isAdmin) return true;
            final ord = item['orders'];
            if (ord == null) return false;
            if (isVendor) {
              return ord['vendor_id']?.toString() == currentUser.id;
            }
            return ord['user_id']?.toString() == currentUser.id;
          })
          .map<DeliveryModel>((item) {
            final data = Map<String, dynamic>.from(item);
            return _mapToDeliveryModel(data);
          })
          .toList();

      if (isAdmin) {
        try {
          final deliveryOrderIds = deliveries
              .map((d) => d.orderId)
              .whereType<String>()
              .toSet();

          final cancelledOrdersRes = await SupabaseService.client
              .from('orders')
              .select('''
                *,
                vendor:users!vendor_id(full_name, business_name),
                customer:users!user_id(full_name, phone_number),
                campus_locations!delivery_location_id(name),
                order_items(product_name, quantity, weight_grams)
              ''')
              .inFilter('order_status', ['cancelled', 'rejected'])
              .order('created_at', ascending: false);

          for (final ord in cancelledOrdersRes) {
            final orderId = ord['id']?.toString();
            if (orderId != null && !deliveryOrderIds.contains(orderId)) {
              final customer = ord['customer'] as Map<String, dynamic>? ?? {};
              final vendor = ord['vendor'] as Map<String, dynamic>? ?? {};
              final location =
                  ord['campus_locations'] as Map<String, dynamic>? ?? {};
              final items = ord['order_items'] as List? ?? [];

              String packageName = 'AeroDrop Package';
              double packageWeight = 0.0;
              if (items.isNotEmpty) {
                final names = items
                    .map(
                      (i) =>
                          '${i['product_name'] ?? ''} (x${i['quantity'] ?? 1})',
                    )
                    .where((n) => n.isNotEmpty)
                    .toList();
                packageName = names.join(', ');
                int totalWeightGrams = 0;
                for (final i in items) {
                  final w = (i['weight_grams'] as num?)?.toInt() ?? 0;
                  final q = (i['quantity'] as num?)?.toInt() ?? 1;
                  totalWeightGrams += w * q;
                }
                packageWeight = totalWeightGrams / 1000.0;
              }

              final senderName =
                  vendor['business_name']?.toString() ??
                  vendor['full_name']?.toString() ??
                  'Unknown Vendor';
              final recipientName =
                  customer['full_name']?.toString() ?? 'Unknown Customer';
              final recipientPhone = customer['phone_number']?.toString() ?? '';
              final deliveryAddress =
                  location['name']?.toString() ?? 'UCLM Campus';
              final cancellationReason =
                  ord['cancellation_reason']?.toString() ?? 'customer';

              deliveries.add(
                DeliveryModel(
                  id: orderId,
                  orderId: orderId,
                  senderName: senderName,
                  recipientName: recipientName,
                  recipientPhone: recipientPhone,
                  deliveryAddress: deliveryAddress,
                  packageName: packageName,
                  packageWeight: packageWeight,
                  packageType: 'Food',
                  status: DeliveryStatus.cancelled,
                  noDroneDispatched: true,
                  cancellationReason: cancellationReason,
                  orderStatus: ord['order_status']?.toString(),
                  eta: 'N/A',
                  createdAt: ord['created_at'] != null
                      ? DateTime.tryParse(ord['created_at'].toString()) ??
                            DateTime.now()
                      : DateTime.now(),
                  progress: 0.0,
                  paymentAmount: (ord['total_amount'] as num?)?.toDouble(),
                  pickupLocationName: senderName,
                  dropoffLocationName: deliveryAddress,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error loading cancelled orders without delivery: $e');
        }

        deliveries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      state = deliveries;
    } catch (error) {
      debugPrint('Load deliveries failed: $error');
    }
  }

  Future<String?> _checkWeatherSafety() async {
    if (!SupabaseService.isConfigured) return null;

    try {
      final weather = await SupabaseService.client
          .from('weather_safety')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (weather == null) {
        return 'No weather record configured. Drone dispatch blocked.';
      }

      final weatherStatus = weather['safety_status']?.toString();
      final dispatchEnabled = weather['dispatch_enabled'] == true;
      final windSpeed = _toDouble(weather['wind_speed_kph']);
      final temp = _toDouble(weather['temperature_c']);
      final maxWind = _toDouble(weather['max_safe_wind_kph'], 35);
      final maxTemp = _toDouble(weather['max_safe_temperature_c'], 38);
      final advisory =
          weather['advisory_message']?.toString() ??
          'Weather conditions are unsafe for dispatch.';

      if (weatherStatus == 'grounded' || !dispatchEnabled) {
        return advisory;
      }

      if (windSpeed > maxWind) {
        return 'Dispatch disabled. Wind speed is too high.';
      }

      if (temp > maxTemp) {
        return 'Dispatch disabled. Temperature is too high.';
      }

      return null;
    } catch (error) {
      debugPrint('Weather safety check failed: $error');
      return 'Weather check failed: $error';
    }
  }

  Future<void> _insertStatusLog({
    required String deliveryId,
    required String status,
    required String message,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      // Plain text status column — no UUID lookup needed.
      await SupabaseService.client.from('delivery_status_logs').insert({
        'delivery_id': deliveryId,
        'status': status,
        'message': message,
      });
    } catch (error) {
      debugPrint('Delivery status log insert failed: $error');
    }
  }

  void updateDeliveryStatus(
    String id,
    DeliveryStatus status, {
    String? droneId,
  }) {
    state = state.map((delivery) {
      if (delivery.id == id) {
        return delivery.copyWith(
          status: status,
          droneId: droneId ?? delivery.droneId,
          progress: status == DeliveryStatus.delivered
              ? 1.0
              : (status == DeliveryStatus.inTransit ? 0.1 : 0.0),
          eta: status == DeliveryStatus.delivered
              ? '0 mins'
              : (status == DeliveryStatus.inTransit ? '10 mins' : 'TBD'),
        );
      }

      return delivery;
    }).toList();

    if (SupabaseService.isConfigured) {
      SupabaseService.client
          .from('deliveries')
          .update({'status': status.name, 'drone_id': droneId})
          .eq('id', id)
          .then((_) async {
            await _insertStatusLog(
              deliveryId: id,
              status: status.name,
              message: 'Delivery status updated to ${status.name}.',
            );
          })
          .catchError((error) {
            debugPrint('Delivery status update failed: $error');
          });
    }
  }

  Future<String?> acceptDelivery(String deliveryId) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured';

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return 'You must be logged in.';

    try {
      final deliveryData = await SupabaseService.client
          .from('deliveries')
          .select('*, orders!order_id(*, order_items(weight_grams, quantity))')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) {
        return 'Delivery request not found.';
      }

      // Plain text status column
      final statusStr = deliveryData['status']?.toString();
      if (statusStr == 'cancelled') {
        return 'This delivery request has already been cancelled.';
      }

      final orderMap = deliveryData['orders'] as Map<String, dynamic>?;
      final orderItems = orderMap?['order_items'] as List? ?? [];

      int totalWeightGrams = 0;
      for (final item in orderItems) {
        final w = (item['weight_grams'] as num?)?.toInt() ?? 0;
        final q = (item['quantity'] as num?)?.toInt() ?? 1;
        totalWeightGrams += w * q;
      }
      final packageWeight = totalWeightGrams / 1000.0;

      if (packageWeight > 0.5) {
        return 'Package is too heavy. Maximum supported drone payload is 0.5 kg.';
      }

      final weatherError = await _checkWeatherSafety();
      if (weatherError != null) {
        return 'Weather check failed: $weatherError';
      }

      // Query DRN-001 drone UUID dynamically
      final droneLookup = await SupabaseService.client
          .from('drones')
          .select()
          .eq('drone_code', 'DRN-001')
          .maybeSingle();

      if (droneLookup == null) {
        return 'AeroCarrier Alpha drone configuration (DRN-001) not found in database.';
      }

      final droneUuid = droneLookup['id'].toString();
      // status is now a plain text column
      final droneStatus = droneLookup['status']?.toString().toLowerCase();
      if (droneStatus != 'available') {
        return 'The drone is currently busy. Please wait until it becomes available.';
      }

      const minimumBatteryForDelivery = 10.0;
      final droneBattery = _toDouble(droneLookup['battery_level'], 100.0);

      if (droneBattery < minimumBatteryForDelivery) {
        return 'Drone battery is too low. Please recharge the drone before accepting deliveries.';
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final existingDel = state.where((d) => d.id == deliveryId).firstOrNull;
      final weather = ref.read(weatherProvider);
      final pickupLoc =
          existingDel?.pickupLocationCoords ??
          _coordinatesForLocation(
            existingDel?.pickupLocationName ??
                deliveryData['pickup_location_name']?.toString() ??
                'Main Building',
          );
      // The pin, from the loaded delivery or straight from the row just read
      final rowPinLat = _toDoubleOrNull(deliveryData['custom_dropoff_lat']);
      final rowPinLng = _toDoubleOrNull(deliveryData['custom_dropoff_lng']);
      final dropoffLoc =
          existingDel?.customDropoffCoords ??
          (rowPinLat != null && rowPinLng != null
              ? (rowPinLat, rowPinLng)
              : null) ??
          existingDel?.dropoffLocationCoords ??
          _coordinatesForLocation(
            existingDel?.dropoffLocationName ??
                existingDel?.deliveryAddress ??
                deliveryData['delivery_address']?.toString() ??
                'Campus',
          );
      final distMeters = DroneFlightCalculator.calculateDistanceMeters(
        startLat: pickupLoc.$1,
        startLng: pickupLoc.$2,
        endLat: dropoffLoc.$1,
        endLng: dropoffLoc.$2,
      );
      final effSpeed = DroneFlightCalculator.calculateEffectiveSpeed(
        isLoaded: true,
        payloadKg: packageWeight,
        isCaution: weather.isCaution,
      );
      final estimatedSecs = DroneFlightCalculator.calculateDurationSeconds(
        distanceMeters: distMeters,
        effectiveSpeed: effSpeed,
      ).round();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          // Assigned, not flying: the delivery waits in 'assigning' until
          // the operator sends it to the drone (python_script/aio.py), and
          // the bridge moves it to in_transit after takeoff.
          .update({
            'status': 'assigning',
            'drone_id': droneUuid,
            'estimated_delivery_seconds': estimatedSecs,
            'progress': 0.0,
            'updated_at': nowStr,
          })
          .eq('id', deliveryId)
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .single();

      await SupabaseService.client
          .from('drones')
          .update({'status': 'assigned'})
          .eq('id', droneUuid);

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'accepted',
        message: 'Delivery request accepted by admin.',
      );

      ref
          .read(droneProvider.notifier)
          .updateStatus('DRN-001', DroneStatus.assigned);

      final updatedDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(updatedResponse),
      );

      state = state
          .map((d) => d.id == deliveryId ? updatedDelivery : d)
          .toList();

      await refreshPendingDeliveriesCount();
      try {
        ref.read(orderProvider.notifier).loadOrders();
        ref.read(vendorOrdersProvider.notifier).loadOrders();
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('Accept delivery error: $e');
      return 'Failed to accept delivery: ${e.toString()}';
    }
  }

  Future<bool> verifyPackage({
    required String deliveryId,
    required String remarks,
    String photoUrl = '',
  }) async {
    return true;
  }

  Future<String?> rejectDelivery(
    String deliveryId, {
    String reason = 'Rejected by admin',
  }) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured';

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return 'You must be logged in.';

    try {
      final deliveryData = await SupabaseService.client
          .from('deliveries')
          .select('status')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) return 'Delivery not found.';
      final statusStr = deliveryData['status']?.toString();
      if (statusStr == 'cancelled') {
        return 'This delivery request has already been cancelled.';
      }
      if (statusStr == 'delivered') {
        return 'This delivery has already been completed.';
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Cancelling the delivery fires handle_delivery_drone_release, which
      // sends an assigned drone back to base.
      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'cancelled',
            'delivery_completed_at': nowStr, // mark end time
          })
          .eq('id', deliveryId)
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .single();

      final orderId =
          updatedResponse['order_id']?.toString() ??
          updatedResponse['orders']?['id']?.toString();
      // Cancelling the order is what refunds a simulated payment, restores
      // stock and notifies the customer, vendor and admins, all in triggers.
      if (orderId != null) {
        await SupabaseService.client
            .from('orders')
            .update({
              'order_status': 'cancelled',
              'cancellation_reason': 'admin_rejected',
              'updated_at': nowStr,
            })
            .eq('id', orderId);
      }

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'cancelled',
        message:
            'Delivery request rejected by admin ${currentUser.id}: $reason',
      );

      final updatedDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(updatedResponse),
      );

      state = state
          .map((d) => d.id == deliveryId ? updatedDelivery : d)
          .toList();

      await refreshPendingDeliveriesCount();

      return null;
    } catch (e) {
      debugPrint('Reject delivery error: $e');
      return 'Failed to reject delivery: ${e.toString()}';
    }
  }

  Future<void> loadAdminDeliveriesFromSupabase() async {
    if (!SupabaseService.isConfigured) return;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('Load admin deliveries skipped: no logged in user.');
      state = [];
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('''
            *,
            pickup_loc:campus_locations!pickup_location_id(id, name, latitude, longitude),
            dropoff_loc:campus_locations!dropoff_location_id(id, name, latitude, longitude),
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final deliveries = (response as List).map<DeliveryModel>((item) {
        final data = Map<String, dynamic>.from(item);
        return _mapToDeliveryModel(data);
      }).toList();

      try {
        final deliveryOrderIds = deliveries
            .map((d) => d.orderId)
            .whereType<String>()
            .toSet();

        final cancelledOrdersRes = await SupabaseService.client
            .from('orders')
            .select('''
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            ''')
            .inFilter('order_status', ['cancelled', 'rejected'])
            .order('created_at', ascending: false);

        for (final ord in cancelledOrdersRes) {
          final orderId = ord['id']?.toString();
          if (orderId != null && !deliveryOrderIds.contains(orderId)) {
            final customer = ord['customer'] as Map<String, dynamic>? ?? {};
            final vendor = ord['vendor'] as Map<String, dynamic>? ?? {};
            final location =
                ord['campus_locations'] as Map<String, dynamic>? ?? {};
            final items = ord['order_items'] as List? ?? [];

            String packageName = 'AeroDrop Package';
            double packageWeight = 0.0;
            if (items.isNotEmpty) {
              final names = items
                  .map(
                    (i) =>
                        '${i['product_name'] ?? ''} (x${i['quantity'] ?? 1})',
                  )
                  .where((n) => n.isNotEmpty)
                  .toList();
              packageName = names.join(', ');
              int totalWeightGrams = 0;
              for (final i in items) {
                final w = (i['weight_grams'] as num?)?.toInt() ?? 0;
                final q = (i['quantity'] as num?)?.toInt() ?? 1;
                totalWeightGrams += w * q;
              }
              packageWeight = totalWeightGrams / 1000.0;
            }

            final senderName =
                vendor['business_name']?.toString() ??
                vendor['full_name']?.toString() ??
                'Unknown Vendor';
            final recipientName =
                customer['full_name']?.toString() ?? 'Unknown Customer';
            final recipientPhone = customer['phone_number']?.toString() ?? '';
            final deliveryAddress =
                location['name']?.toString() ?? 'UCLM Campus';
            final cancellationReason =
                ord['cancellation_reason']?.toString() ?? 'customer';

            deliveries.add(
              DeliveryModel(
                id: orderId,
                orderId: orderId,
                senderName: senderName,
                recipientName: recipientName,
                recipientPhone: recipientPhone,
                deliveryAddress: deliveryAddress,
                packageName: packageName,
                packageWeight: packageWeight,
                packageType: 'Food',
                status: DeliveryStatus.cancelled,
                noDroneDispatched: true,
                cancellationReason: cancellationReason,
                orderStatus: ord['order_status']?.toString(),
                eta: 'N/A',
                createdAt: ord['created_at'] != null
                    ? DateTime.tryParse(ord['created_at'].toString()) ??
                          DateTime.now()
                    : DateTime.now(),
                progress: 0.0,
                paymentAmount: (ord['total_amount'] as num?)?.toDouble(),
                pickupLocationName: senderName,
                dropoffLocationName: deliveryAddress,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading cancelled orders without delivery: $e');
      }

      deliveries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = deliveries;
      await refreshPendingDeliveriesCount();
    } catch (error) {
      debugPrint('Load admin deliveries failed: $error');
    }
  }

  Future<void> refreshPendingDeliveriesCount() async {
    // Computed reactively via pendingDeliveriesCountProvider from deliveryProvider.
  }

  void clearDeliveries() {
    state = [];
  }
}

final pendingDeliveriesCountProvider = Provider<int>((ref) {
  final deliveries = ref.watch(deliveryProvider);
  return deliveries
      .where(
        (d) =>
            d.status == DeliveryStatus.pending ||
            d.status == DeliveryStatus.assigning ||
            d.status == DeliveryStatus.inTransit,
      )
      .length;
});

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, List<DeliveryModel>>((ref) {
      return DeliveryNotifier(ref);
    });
