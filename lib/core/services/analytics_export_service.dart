import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'supabase_service.dart';

// ── Date Range Presets ────────────────────────────────────────────────────────

enum DateRangePreset {
  today,
  last7Days,
  last30Days,
  thisMonth,
  custom,
}

class AnalyticsDateRange {
  final DateRangePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const AnalyticsDateRange({
    required this.preset,
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory AnalyticsDateRange.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return AnalyticsDateRange(
      preset: DateRangePreset.today,
      startDate: start,
      endDate: end,
      label: 'Today',
    );
  }

  factory AnalyticsDateRange.last7Days() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    return AnalyticsDateRange(
      preset: DateRangePreset.last7Days,
      startDate: start,
      endDate: todayEnd,
      label: 'Last 7 Days',
    );
  }

  factory AnalyticsDateRange.last30Days() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));
    return AnalyticsDateRange(
      preset: DateRangePreset.last30Days,
      startDate: start,
      endDate: todayEnd,
      label: 'Last 30 Days',
    );
  }

  factory AnalyticsDateRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return AnalyticsDateRange(
      preset: DateRangePreset.thisMonth,
      startDate: start,
      endDate: todayEnd,
      label: 'This Month',
    );
  }

  factory AnalyticsDateRange.custom(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return AnalyticsDateRange(
      preset: DateRangePreset.custom,
      startDate: s,
      endDate: e,
      label: 'Custom Range',
    );
  }

  String get fileDateString {
    final sStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final eStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    return '${sStr}_to_$eStr';
  }

  String get formattedRange {
    final sStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final eStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    return '$sStr to $eStr';
  }
}

// ── Models for Aggregated Report Data ─────────────────────────────────────────

class OrderExportItem {
  final String shortId;
  final String fullId;
  final DateTime createdAt;
  final String storeName;
  final String customerAnonymized;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double totalAmount;
  final String? cancellationReason;
  final double? deliveryDurationMinutes;

  const OrderExportItem({
    required this.shortId,
    required this.fullId,
    required this.createdAt,
    required this.storeName,
    required this.customerAnonymized,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.totalAmount,
    this.cancellationReason,
    this.deliveryDurationMinutes,
  });
}

class VendorAnalyticsItem {
  final String vendorId;
  final String storeName;
  final int orderCount;
  final int deliveredCount;
  final double revenue;
  final double averageRating;
  final int reviewCount;

  const VendorAnalyticsItem({
    required this.vendorId,
    required this.storeName,
    required this.orderCount,
    required this.deliveredCount,
    required this.revenue,
    required this.averageRating,
    required this.reviewCount,
  });
}

class DailyAnalyticsItem {
  final String dateString;
  final DateTime date;
  final int orderCount;
  final int deliveredCount;
  final double revenue;

  const DailyAnalyticsItem({
    required this.dateString,
    required this.date,
    required this.orderCount,
    required this.deliveredCount,
    required this.revenue,
  });
}

class PaymentSplitItem {
  final String methodLabel;
  final String rawMethod;
  final int count;
  final double totalAmount;

  const PaymentSplitItem({
    required this.methodLabel,
    required this.rawMethod,
    required this.count,
    required this.totalAmount,
  });
}

class AnalyticsReportData {
  final AnalyticsDateRange dateRange;
  final DateTime generatedAt;
  final int totalOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final int cancelledByCustomer;
  final int cancelledByVendor;
  final int cancelledByWeather;
  final int cancelledOther;
  final double totalRevenue;
  final double refundedAmount;
  final double avgDeliveryTimeMinutes;
  final int deliveriesCompleted;
  final Map<String, int> weatherStatusCounts;
  final List<VendorAnalyticsItem> vendors;
  final List<DailyAnalyticsItem> dailyStats;
  final List<PaymentSplitItem> paymentSplit;
  final List<OrderExportItem> orders;

  const AnalyticsReportData({
    required this.dateRange,
    required this.generatedAt,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.cancelledByCustomer,
    required this.cancelledByVendor,
    required this.cancelledByWeather,
    required this.cancelledOther,
    required this.totalRevenue,
    required this.refundedAmount,
    required this.avgDeliveryTimeMinutes,
    required this.deliveriesCompleted,
    required this.weatherStatusCounts,
    required this.vendors,
    required this.dailyStats,
    required this.paymentSplit,
    required this.orders,
  });

  bool get isEmpty => orders.isEmpty;
}

// ── Export Service Implementation ─────────────────────────────────────────────

class AnalyticsExportService {
  /// Anonymizes customer full name to "Firstname L." format matching reviews RPC.
  /// (First name + first letter of second word, e.g. "Juan Dela Cruz" -> "Juan D.")
  /// Never reveals email, phone, or full last name.
  static String anonymizeCustomerName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return 'Customer';
    }
    final clean = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final parts = clean.split(' ');
    if (parts.length == 1) {
      return parts.first;
    }
    final first = parts.first;
    final secondInitial = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    return secondInitial.isNotEmpty ? '$first $secondInitial.' : first;
  }

  /// Formats raw payment method identifier to a readable label.
  static String formatPaymentMethod(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m == 'gcash_simulated' || m == 'gcash') return 'GCash';
    if (m == 'card_simulated' || m == 'card') return 'Credit/Debit Card';
    if (m == 'cash_on_delivery' || m == 'cash') return 'Cash on Delivery (Legacy)';
    return m.isEmpty ? 'Unspecified' : m;
  }

  /// Formats raw order status into a readable string.
  static String formatOrderStatus(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    return switch (s) {
      'pending' => 'Pending',
      'confirmed' => 'Confirmed',
      'preparing' => 'Preparing',
      'ready_for_delivery' || 'ready' => 'Ready for Delivery',
      'in_transit' || 'intransit' => 'In Transit',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      'rejected' => 'Rejected',
      'failed' => 'Failed',
      _ => s.isEmpty ? 'Unknown' : s[0].toUpperCase() + s.substring(1),
    };
  }

  /// Formats currency with Philippine Peso symbol.
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Fetches and aggregates real Supabase data for the given date range.
  static Future<AnalyticsReportData> fetchAnalyticsData(
    AnalyticsDateRange range,
  ) async {
    final now = DateTime.now();

    if (!SupabaseService.isConfigured) {
      return AnalyticsReportData(
        dateRange: range,
        generatedAt: now,
        totalOrders: 0,
        deliveredOrders: 0,
        cancelledOrders: 0,
        cancelledByCustomer: 0,
        cancelledByVendor: 0,
        cancelledByWeather: 0,
        cancelledOther: 0,
        totalRevenue: 0.0,
        refundedAmount: 0.0,
        avgDeliveryTimeMinutes: 0.0,
        deliveriesCompleted: 0,
        weatherStatusCounts: {},
        vendors: [],
        dailyStats: [],
        paymentSplit: [],
        orders: [],
      );
    }

    try {
      // 1. Query orders within date range with customer, vendor, and delivery details
      final ordersRes = await SupabaseService.client
          .from('orders')
          .select('''
            id,
            user_id,
            vendor_id,
            order_status,
            cancellation_reason,
            subtotal,
            delivery_fee,
            total_amount,
            payment_method,
            payment_status,
            created_at,
            customer:users!user_id(full_name),
            vendor:users!vendor_id(business_name, full_name),
            deliveries(id, status, delivery_started_at, delivery_completed_at, estimated_delivery_seconds)
          ''')
          .gte('created_at', range.startDate.toUtc().toIso8601String())
          .lte('created_at', range.endDate.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> rawOrders =
          List<Map<String, dynamic>>.from(ordersRes);

      // 2. Query vendor ratings summary
      Map<String, Map<String, dynamic>> ratingsByVendor = {};
      try {
        final ratingsRes = await SupabaseService.client
            .from('vendor_ratings_summary')
            .select();
        for (final r in ratingsRes) {
          final vId = r['vendor_id']?.toString();
          if (vId != null && vId.isNotEmpty) {
            ratingsByVendor[vId] = Map<String, dynamic>.from(r);
          }
        }
      } catch (e) {
        debugPrint('AnalyticsExport: ratings fetch skipped/empty: $e');
      }

      // 3. Query weather status records
      Map<String, int> weatherStatusCounts = {
        'safe': 0,
        'caution': 0,
        'grounded': 0,
      };
      try {
        final weatherRes = await SupabaseService.client
            .from('weather_safety')
            .select('safety_status');
        for (final w in weatherRes) {
          final status = (w['safety_status']?.toString() ?? 'safe').toLowerCase();
          weatherStatusCounts[status] = (weatherStatusCounts[status] ?? 0) + 1;
        }
      } catch (_) {}

      // 4. Aggregate metrics
      int totalOrders = rawOrders.length;
      int deliveredOrders = 0;
      int cancelledOrders = 0;
      int cancelledByCustomer = 0;
      int cancelledByVendor = 0;
      int cancelledByWeather = 0;
      int cancelledOther = 0;
      double totalRevenue = 0.0;
      double refundedAmount = 0.0;
      int deliveriesCompletedCount = 0;
      List<double> completedFlightMinutes = [];

      List<OrderExportItem> exportOrders = [];
      Map<String, Map<String, dynamic>> vendorBuckets = {};
      Map<String, Map<String, dynamic>> dailyBuckets = {};
      Map<String, Map<String, dynamic>> paymentBuckets = {
        'GCash': {'count': 0, 'amount': 0.0, 'raw': 'gcash_simulated'},
        'Credit/Debit Card': {'count': 0, 'amount': 0.0, 'raw': 'card_simulated'},
        'Cash on Delivery (Legacy)': {'count': 0, 'amount': 0.0, 'raw': 'cash_on_delivery'},
      };

      for (final o in rawOrders) {
        final id = o['id']?.toString() ?? '';
        final shortId = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
        final rawCreatedAt = o['created_at'] != null
            ? DateTime.tryParse(o['created_at'].toString())?.toLocal() ?? now
            : now;
        final oStatus = (o['order_status']?.toString() ?? 'pending').toLowerCase();
        final pStatus = (o['payment_status']?.toString() ?? 'pending').toLowerCase();
        final pMethod = o['payment_method']?.toString() ?? 'gcash_simulated';
        final cancelReason = (o['cancellation_reason']?.toString() ?? '').toLowerCase();
        final totalAmount = (double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0);

        // Vendor name
        final vendorObj = o['vendor'] as Map<String, dynamic>?;
        final vId = o['vendor_id']?.toString() ?? '';
        final storeName = vendorObj?['business_name']?.toString() ??
            vendorObj?['full_name']?.toString() ??
            'Unknown Vendor';

        // Customer anonymization
        final customerObj = o['customer'] as Map<String, dynamic>?;
        final rawCustName = customerObj?['full_name']?.toString();
        final anonCustomer = anonymizeCustomerName(rawCustName);

        // Delivery details & flight duration
        double? flightMinutes;
        final deliveriesRaw = o['deliveries'];
        Map<String, dynamic>? deliveryMap;
        if (deliveriesRaw is List && deliveriesRaw.isNotEmpty) {
          deliveryMap = Map<String, dynamic>.from(deliveriesRaw.first);
        } else if (deliveriesRaw is Map<String, dynamic>) {
          deliveryMap = deliveriesRaw;
        }

        final dStatus = deliveryMap?['status']?.toString().toLowerCase();
        if (deliveryMap != null) {
          final started = deliveryMap['delivery_started_at'] != null
              ? DateTime.tryParse(deliveryMap['delivery_started_at'].toString())
              : null;
          final completed = deliveryMap['delivery_completed_at'] != null
              ? DateTime.tryParse(deliveryMap['delivery_completed_at'].toString())
              : null;
          if (started != null && completed != null) {
            final secs = completed.difference(started).inSeconds;
            if (secs > 0) {
              flightMinutes = secs / 60.0;
            }
          }
        }

        final isDelivered = oStatus == 'delivered' || dStatus == 'delivered';
        final isCancelled = oStatus == 'cancelled' || oStatus == 'rejected' || dStatus == 'cancelled';

        if (isDelivered) {
          deliveredOrders++;
          deliveriesCompletedCount++;
          if (flightMinutes != null) {
            completedFlightMinutes.add(flightMinutes);
          }
          if (pStatus == 'paid') {
            totalRevenue += totalAmount;
          }
        }

        if (isCancelled) {
          cancelledOrders++;
          if (cancelReason == 'customer' || cancelReason.contains('customer')) {
            cancelledByCustomer++;
          } else if (cancelReason == 'vendor' || cancelReason.contains('vendor') || cancelReason.contains('reject')) {
            cancelledByVendor++;
          } else if (cancelReason == 'weather_grounded' || cancelReason.contains('weather')) {
            cancelledByWeather++;
          } else {
            cancelledOther++;
          }
        }

        if (pStatus == 'refunded') {
          refundedAmount += totalAmount;
        }

        // Payment split bucket
        final formattedMethod = formatPaymentMethod(pMethod);
        if (!paymentBuckets.containsKey(formattedMethod)) {
          paymentBuckets[formattedMethod] = {
            'count': 0,
            'amount': 0.0,
            'raw': pMethod,
          };
        }
        paymentBuckets[formattedMethod]!['count'] =
            (paymentBuckets[formattedMethod]!['count'] as int) + 1;
        paymentBuckets[formattedMethod]!['amount'] =
            (paymentBuckets[formattedMethod]!['amount'] as double) + totalAmount;

        // Vendor aggregation
        if (!vendorBuckets.containsKey(vId)) {
          vendorBuckets[vId] = {
            'storeName': storeName,
            'orderCount': 0,
            'deliveredCount': 0,
            'revenue': 0.0,
          };
        }
        vendorBuckets[vId]!['orderCount'] =
            (vendorBuckets[vId]!['orderCount'] as int) + 1;
        if (isDelivered) {
          vendorBuckets[vId]!['deliveredCount'] =
              (vendorBuckets[vId]!['deliveredCount'] as int) + 1;
          if (pStatus == 'paid') {
            vendorBuckets[vId]!['revenue'] =
                (vendorBuckets[vId]!['revenue'] as double) + totalAmount;
          }
        }

        // Daily aggregation
        final dateKey =
            '${rawCreatedAt.year}-${rawCreatedAt.month.toString().padLeft(2, '0')}-${rawCreatedAt.day.toString().padLeft(2, '0')}';
        if (!dailyBuckets.containsKey(dateKey)) {
          dailyBuckets[dateKey] = {
            'date': DateTime(rawCreatedAt.year, rawCreatedAt.month, rawCreatedAt.day),
            'orderCount': 0,
            'deliveredCount': 0,
            'revenue': 0.0,
          };
        }
        dailyBuckets[dateKey]!['orderCount'] =
            (dailyBuckets[dateKey]!['orderCount'] as int) + 1;
        if (isDelivered) {
          dailyBuckets[dateKey]!['deliveredCount'] =
              (dailyBuckets[dateKey]!['deliveredCount'] as int) + 1;
          if (pStatus == 'paid') {
            dailyBuckets[dateKey]!['revenue'] =
                (dailyBuckets[dateKey]!['revenue'] as double) + totalAmount;
          }
        }

        // Add to order item list
        exportOrders.add(OrderExportItem(
          shortId: shortId,
          fullId: id,
          createdAt: rawCreatedAt,
          storeName: storeName,
          customerAnonymized: anonCustomer,
          status: isDelivered ? 'Delivered' : (isCancelled ? 'Cancelled' : formatOrderStatus(oStatus)),
          paymentMethod: formattedMethod,
          paymentStatus: pStatus.isEmpty ? 'Pending' : (pStatus[0].toUpperCase() + pStatus.substring(1)),
          totalAmount: totalAmount,
          cancellationReason: cancelReason.isNotEmpty ? cancelReason : null,
          deliveryDurationMinutes: flightMinutes,
        ));
      }

      // Compute average delivery time
      double avgFlightTime = 0.0;
      if (completedFlightMinutes.isNotEmpty) {
        final sumMins = completedFlightMinutes.reduce((a, b) => a + b);
        avgFlightTime = sumMins / completedFlightMinutes.length;
      }

      // Build vendor analytics items
      final List<VendorAnalyticsItem> vendorList = [];
      vendorBuckets.forEach((vId, data) {
        final ratings = ratingsByVendor[vId];
        final avgRating = (ratings?['average_rating'] as num?)?.toDouble() ?? 0.0;
        final revCount = (ratings?['review_count'] as num?)?.toInt() ?? 0;

        vendorList.add(VendorAnalyticsItem(
          vendorId: vId,
          storeName: data['storeName'] as String,
          orderCount: data['orderCount'] as int,
          deliveredCount: data['deliveredCount'] as int,
          revenue: data['revenue'] as double,
          averageRating: avgRating,
          reviewCount: revCount,
        ));
      });
      vendorList.sort((a, b) => b.revenue.compareTo(a.revenue));

      // Build daily stats list (sorted chronologically)
      final List<DailyAnalyticsItem> dailyList = [];
      dailyBuckets.forEach((dateStr, data) {
        dailyList.add(DailyAnalyticsItem(
          dateString: dateStr,
          date: data['date'] as DateTime,
          orderCount: data['orderCount'] as int,
          deliveredCount: data['deliveredCount'] as int,
          revenue: data['revenue'] as double,
        ));
      });
      dailyList.sort((a, b) => a.date.compareTo(b.date));

      // Build payment split list
      final List<PaymentSplitItem> paymentSplitList = [];
      paymentBuckets.forEach((label, data) {
        if ((data['count'] as int) > 0 || (data['amount'] as double) > 0) {
          paymentSplitList.add(PaymentSplitItem(
            methodLabel: label,
            rawMethod: data['raw'] as String,
            count: data['count'] as int,
            totalAmount: data['amount'] as double,
          ));
        }
      });
      paymentSplitList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      return AnalyticsReportData(
        dateRange: range,
        generatedAt: now,
        totalOrders: totalOrders,
        deliveredOrders: deliveredOrders,
        cancelledOrders: cancelledOrders,
        cancelledByCustomer: cancelledByCustomer,
        cancelledByVendor: cancelledByVendor,
        cancelledByWeather: cancelledByWeather,
        cancelledOther: cancelledOther,
        totalRevenue: totalRevenue,
        refundedAmount: refundedAmount,
        avgDeliveryTimeMinutes: avgFlightTime,
        deliveriesCompleted: deliveriesCompletedCount,
        weatherStatusCounts: weatherStatusCounts,
        vendors: vendorList,
        dailyStats: dailyList,
        paymentSplit: paymentSplitList,
        orders: exportOrders,
      );
    } catch (e, st) {
      debugPrint('AnalyticsExport fetch error: $e\n$st');
      return AnalyticsReportData(
        dateRange: range,
        generatedAt: now,
        totalOrders: 0,
        deliveredOrders: 0,
        cancelledOrders: 0,
        cancelledByCustomer: 0,
        cancelledByVendor: 0,
        cancelledByWeather: 0,
        cancelledOther: 0,
        totalRevenue: 0.0,
        refundedAmount: 0.0,
        avgDeliveryTimeMinutes: 0.0,
        deliveriesCompleted: 0,
        weatherStatusCounts: {},
        vendors: [],
        dailyStats: [],
        paymentSplit: [],
        orders: [],
      );
    }
  }

  // ── CSV Generator ─────────────────────────────────────────────────────────

  /// Generates a complete UTF-8 BOM CSV byte array containing executive
  /// summary sections and the complete order list.
  static Uint8List generateCsv(AnalyticsReportData data) {
    final List<List<dynamic>> rows = [];

    // Header & Metadata
    rows.add(['AERODROP ANALYTICS REPORT']);
    rows.add(['Date Range', data.dateRange.formattedRange]);
    rows.add(['Generated At', data.generatedAt.toLocal().toString().split('.').first]);
    rows.add([]);

    // 1. Executive Summary
    rows.add(['EXECUTIVE SUMMARY']);
    rows.add(['Metric', 'Value']);
    rows.add(['Total Orders', data.totalOrders]);
    rows.add(['Delivered Orders', data.deliveredOrders]);
    rows.add(['Cancelled Orders (Total)', data.cancelledOrders]);
    rows.add(['- Cancelled by Customer', data.cancelledByCustomer]);
    rows.add(['- Cancelled by Vendor', data.cancelledByVendor]);
    rows.add(['- Weather Grounded', data.cancelledByWeather]);
    rows.add(['- Other Cancellations', data.cancelledOther]);
    rows.add(['Total Revenue (Delivered & Paid)', formatCurrency(data.totalRevenue)]);
    rows.add(['Total Refunded', formatCurrency(data.refundedAmount)]);
    rows.add(['Completed Deliveries', data.deliveriesCompleted]);
    rows.add([
      'Average Delivery Time',
      data.avgDeliveryTimeMinutes > 0
          ? '${data.avgDeliveryTimeMinutes.toStringAsFixed(1)} mins'
          : 'N/A',
    ]);
    rows.add([]);

    // 2. Vendor Performance Breakdown
    rows.add(['VENDOR BREAKDOWN']);
    rows.add(['Store Name', 'Total Orders', 'Delivered', 'Revenue', 'Avg Rating', 'Reviews']);
    if (data.vendors.isEmpty) {
      rows.add(['No vendor activity in this period', '-', '-', '-', '-', '-']);
    } else {
      for (final v in data.vendors) {
        rows.add([
          v.storeName,
          v.orderCount,
          v.deliveredCount,
          formatCurrency(v.revenue),
          v.averageRating > 0 ? v.averageRating.toStringAsFixed(1) : 'No reviews',
          v.reviewCount,
        ]);
      }
    }
    rows.add([]);

    // 3. Payment Method Split
    rows.add(['PAYMENT METHOD SPLIT']);
    rows.add(['Payment Method', 'Order Count', 'Total Amount']);
    if (data.paymentSplit.isEmpty) {
      rows.add(['No payment transactions in this period', '-', '-']);
    } else {
      for (final p in data.paymentSplit) {
        rows.add([p.methodLabel, p.count, formatCurrency(p.totalAmount)]);
      }
    }
    rows.add([]);

    // 4. Daily Volume Breakdown
    rows.add(['DAILY DISPATCH VOLUME']);
    rows.add(['Date', 'Total Orders', 'Delivered', 'Revenue']);
    if (data.dailyStats.isEmpty) {
      rows.add(['No daily dispatch activity in this period', '-', '-', '-']);
    } else {
      for (final d in data.dailyStats) {
        rows.add([
          d.dateString,
          d.orderCount,
          d.deliveredCount,
          formatCurrency(d.revenue),
        ]);
      }
    }
    rows.add([]);

    // 5. Detailed Orders List
    rows.add(['DETAILED ORDER LIST']);
    rows.add([
      'Order ID',
      'Date & Time',
      'Store Name',
      'Customer',
      'Status',
      'Payment Method',
      'Payment Status',
      'Total Amount',
      'Flight Duration (mins)',
    ]);

    if (data.orders.isEmpty) {
      rows.add(['No orders in this period', '', '', '', '', '', '', '', '']);
    } else {
      for (final o in data.orders) {
        final dateStr =
            '${o.createdAt.year}-${o.createdAt.month.toString().padLeft(2, '0')}-${o.createdAt.day.toString().padLeft(2, '0')} ${o.createdAt.hour.toString().padLeft(2, '0')}:${o.createdAt.minute.toString().padLeft(2, '0')}';
        rows.add([
          o.shortId,
          dateStr,
          o.storeName,
          o.customerAnonymized,
          o.status,
          o.paymentMethod,
          o.paymentStatus,
          formatCurrency(o.totalAmount),
          o.deliveryDurationMinutes != null
              ? o.deliveryDurationMinutes!.toStringAsFixed(1)
              : '-',
        ]);
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    // Prefix UTF-8 BOM (\uFEFF) so Excel renders ₱ and special characters accurately
    final bomUtf8 = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bomUtf8);
  }

  // ── PDF Generator ─────────────────────────────────────────────────────────

  /// Generates a branded, multi-page PDF report byte array.
  static Future<Uint8List> generatePdf(AnalyticsReportData data) async {
    final pdf = pw.Document();

    // 1. Load brand image asset if available
    pw.MemoryImage? brandLogo;
    try {
      final logoBytes = await rootBundle.load('assets/images/brand_mark.png');
      brandLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('AnalyticsExport: brand_mark.png load skipped: $e');
    }

    // 2. Load TrueType Fonts for clear text and currency glyph rendering
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final brandPrimary = PdfColor.fromHex('#4F46E5');
    final brandNavy = PdfColor.fromHex('#0F172A');
    final brandCardBg = PdfColor.fromHex('#F8FAFC');
    final brandBorder = PdfColor.fromHex('#E2E8F0');
    final textMuted = PdfColor.fromHex('#64748B');
    final successGreen = PdfColor.fromHex('#10B981');
    final dangerRed = PdfColor.fromHex('#EF4444');

    pw.Widget buildKpiCard(
      String title,
      String value,
      String subtitle, {
      PdfColor? valueColor,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: brandCardBg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: brandBorder, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 8.5,
                color: textMuted,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: valueColor ?? brandNavy,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 8,
                color: textMuted,
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 32,
          marginRight: 32,
          marginTop: 32,
          marginBottom: 32,
        ),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (brandLogo != null)
                      pw.Container(
                        width: 34,
                        height: 34,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.Image(brandLogo),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'AeroDrop Campus Logistics',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: brandNavy,
                          ),
                        ),
                        pw.Text(
                          'Autonomous Drone Delivery Analytics Report',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 9,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: brandCardBg,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: brandBorder),
                      ),
                      child: pw.Text(
                        'Period: ${data.dateRange.formattedRange}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8.5,
                          color: brandNavy,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generated: ${data.generatedAt.toLocal().toString().split('.').first}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 7.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AeroDrop Operational Intelligence • Confidential',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: textMuted,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: brandNavy,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // KPI Cards Grid (2 rows of 3)
            pw.GridView(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                buildKpiCard(
                  'Total Revenue',
                  formatCurrency(data.totalRevenue),
                  'Delivered & paid orders only',
                  valueColor: brandPrimary,
                ),
                buildKpiCard(
                  'Total Orders',
                  '${data.totalOrders}',
                  'Across all vendors',
                ),
                buildKpiCard(
                  'Delivered Orders',
                  '${data.deliveredOrders}',
                  '${data.totalOrders > 0 ? (data.deliveredOrders / data.totalOrders * 100).toStringAsFixed(1) : "100"}% delivery rate',
                  valueColor: successGreen,
                ),
                buildKpiCard(
                  'Cancelled Orders',
                  '${data.cancelledOrders}',
                  'Cust: ${data.cancelledByCustomer} • Vend: ${data.cancelledByVendor} • WX: ${data.cancelledByWeather}',
                  valueColor: data.cancelledOrders > 0 ? dangerRed : brandNavy,
                ),
                buildKpiCard(
                  'Avg Delivery Time',
                  data.avgDeliveryTimeMinutes > 0
                      ? '${data.avgDeliveryTimeMinutes.toStringAsFixed(1)} mins'
                      : 'N/A',
                  '${data.deliveriesCompleted} dispatches completed',
                ),
                buildKpiCard(
                  'Refunded Amount',
                  formatCurrency(data.refundedAmount),
                  'Cancelled & refunded payments',
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Vendor Breakdown Table
            pw.Text(
              'Store & Vendor Performance',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: brandNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            if (data.vendors.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: brandCardBg,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'No orders recorded for any store during this period.',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: textMuted),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: brandBorder, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: brandNavy),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                headers: ['Store Name', 'Total Orders', 'Delivered', 'Revenue', 'Rating', 'Reviews'],
                data: data.vendors.map((v) {
                  return [
                    v.storeName,
                    '${v.orderCount}',
                    '${v.deliveredCount}',
                    formatCurrency(v.revenue),
                    v.averageRating > 0 ? '${v.averageRating.toStringAsFixed(1)} ★' : 'No ratings',
                    '${v.reviewCount}',
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 18),

            // Payment Split & Daily Volume Summary (Side by Side)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Payment Method Breakdown
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Method Split',
                        style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandNavy),
                      ),
                      pw.SizedBox(height: 6),
                      if (data.paymentSplit.isEmpty)
                        pw.Text('No payment split data.', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textMuted))
                      else
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: brandBorder, width: 0.5),
                          headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                          headerDecoration: pw.BoxDecoration(color: brandPrimary),
                          cellStyle: pw.TextStyle(font: fontRegular, fontSize: 7.5),
                          headers: ['Method', 'Orders', 'Total Value'],
                          data: data.paymentSplit.map((p) {
                            return [p.methodLabel, '${p.count}', formatCurrency(p.totalAmount)];
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                // Daily Activity Breakdown
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Daily Dispatch Volume',
                        style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandNavy),
                      ),
                      pw.SizedBox(height: 6),
                      if (data.dailyStats.isEmpty)
                        pw.Text('No daily activity data.', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textMuted))
                      else
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: brandBorder, width: 0.5),
                          headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                          headerDecoration: pw.BoxDecoration(color: brandNavy),
                          cellStyle: pw.TextStyle(font: fontRegular, fontSize: 7.5),
                          headers: ['Date', 'Orders', 'Delivered', 'Revenue'],
                          data: data.dailyStats.take(7).map((d) {
                            return [d.dateString, '${d.orderCount}', '${d.deliveredCount}', formatCurrency(d.revenue)];
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 22),

            // Paginated Detailed Order List
            pw.Text(
              'Detailed Order Registry',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: brandNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            if (data.orders.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: brandCardBg,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'No orders found in this period.',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: textMuted),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: brandBorder, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: brandNavy),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 7.5),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                headers: [
                  'ID',
                  'Date',
                  'Store',
                  'Customer',
                  'Status',
                  'Payment',
                  'Pay Status',
                  'Total',
                ],
                data: data.orders.map((o) {
                  final dStr =
                      '${o.createdAt.month.toString().padLeft(2, '0')}/${o.createdAt.day.toString().padLeft(2, '0')} ${o.createdAt.hour.toString().padLeft(2, '0')}:${o.createdAt.minute.toString().padLeft(2, '0')}';
                  return [
                    o.shortId,
                    dStr,
                    o.storeName,
                    o.customerAnonymized,
                    o.status,
                    o.paymentMethod,
                    o.paymentStatus,
                    formatCurrency(o.totalAmount),
                  ];
                }).toList(),
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Cross-Platform File Saving & Sharing ──────────────────────────────────

  /// Saves or shares the exported file across Windows, macOS, Android, iOS, and Web.
  /// Returns the saved file path or name, or null if cancelled.
  static Future<String?> saveOrShareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required BuildContext context,
  }) async {
    try {
      if (kIsWeb) {
        if (fileName.endsWith('.pdf')) {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        } else {
          await FilePicker.platform.saveFile(
            dialogTitle: 'Save Analytics Report',
            fileName: fileName,
            bytes: bytes,
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );
        }
        return fileName;
      }

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final extension = fileName.split('.').last.toLowerCase();
        final selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Analytics Report',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: bytes,
        );

        if (selectedPath != null && selectedPath.isNotEmpty) {
          final file = File(selectedPath);
          if (!file.existsSync() || file.lengthSync() != bytes.length) {
            await file.writeAsBytes(bytes, flush: true);
          }
          return file.path;
        }
        return null;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        if (fileName.endsWith('.pdf')) {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return fileName;
        } else {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes, flush: true);
          await Share.shareXFiles(
            [XFile(tempFile.path, mimeType: mimeType, name: fileName)],
            text: 'AeroDrop Analytics Report: $fileName',
          );
          return fileName;
        }
      }

      // Fallback
      final docDir = await getApplicationDocumentsDirectory();
      final target = File('${docDir.path}/$fileName');
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (e) {
      debugPrint('saveOrShareFile error: $e');
      rethrow;
    }
  }
}
