import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/notification_model.dart';
import 'package:aerodrop/features/notifications/notification_route.dart';

NotificationModel _n(
  String type, {
  String? deliveryId,
  Map<String, dynamic>? metadata,
}) => NotificationModel(
  id: 'n',
  type: type,
  relatedDeliveryId: deliveryId,
  metadata: metadata,
  isRead: false,
);

const _admin = '/admin/notifications';
const _vendor = '/vendor/notifications';
const _user = '/user/notifications';

void main() {
  group('delivery notifications stay in the current role', () {
    final n = _n('delivery_completed', deliveryId: 'd1');

    test('admin', () {
      expect(notificationTarget(n, _admin), (
        location: '/admin/deliveries/details?id=d1',
        isShellTab: false,
      ));
    });
    test('vendor', () {
      expect(notificationTarget(n, _vendor), (
        location: '/vendor/track/details?id=d1',
        isShellTab: false,
      ));
    });
    test('customer', () {
      expect(notificationTarget(n, _user), (
        location: '/user/track/details?id=d1',
        isShellTab: false,
      ));
    });
  });

  group('support reports never open a tracking page', () {
    for (final type in ['support_report', 'support_report_update']) {
      final n = _n(type, deliveryId: 'd1');
      test('$type: admin opens Support', () {
        expect(notificationTarget(n, _admin), (
          location: '/admin/support',
          isShellTab: true,
        ));
      });
      test('$type: customer and vendor stay put', () {
        expect(notificationTarget(n, _user), isNull);
        expect(notificationTarget(n, _vendor), isNull);
      });
    }
  });

  group('order_message', () {
    final n = _n('order_message', metadata: {'order_id': 'o1'});

    test('opens the chat for the current role', () {
      expect(notificationTarget(n, _user), (
        location: '/user/orders/o1/chat',
        isShellTab: false,
      ));
      expect(notificationTarget(n, _vendor), (
        location: '/vendor/orders/o1/chat',
        isShellTab: false,
      ));
      expect(notificationTarget(n, _admin), isNull);
    });

    test('does nothing without an order id', () {
      expect(notificationTarget(_n('order_message'), _user), isNull);
      expect(
        notificationTarget(_n('order_message', metadata: {}), _vendor),
        isNull,
      );
    });
  });

  test('admin-only types route admins and leave others inert', () {
    final stalled = _n('multi_trip_stalled', deliveryId: 'd1');
    expect(notificationTarget(stalled, _admin), (
      location: '/admin/deliveries',
      isShellTab: true,
    ));
    expect(notificationTarget(stalled, _user), isNull);

    final application = _n('vendor_application');
    expect(notificationTarget(application, _admin), (
      location: '/admin/users',
      isShellTab: true,
    ));
    expect(notificationTarget(application, _vendor), isNull);
  });

  test('an unrecognised type does nothing, even with a delivery id', () {
    expect(notificationTarget(_n('something_new'), _user), isNull);
    expect(
      notificationTarget(_n('something_new', deliveryId: 'd1'), _admin),
      isNull,
    );
  });

  test('known types with nowhere to go stay inert', () {
    for (final type in inertNotificationTypes) {
      expect(notificationTarget(_n(type, deliveryId: 'd1'), _user), isNull);
    }
  });

  test('every delivery type opens the delivery, and needs its id', () {
    for (final type in deliveryNotificationTypes) {
      expect(notificationTarget(_n(type, deliveryId: 'd1'), _user), (
        location: '/user/track/details?id=d1',
        isShellTab: false,
      ));
      expect(notificationTarget(_n(type), _user), isNull);
    }
  });

  test('the routed, delivery and inert type sets do not overlap', () {
    const routed = {
      'support_report',
      'support_report_update',
      'order_message',
      'multi_trip_stalled',
      'vendor_application',
    };
    expect(
      deliveryNotificationTypes.intersection(inertNotificationTypes),
      isEmpty,
    );
    expect(deliveryNotificationTypes.intersection(routed), isEmpty);
    expect(inertNotificationTypes.intersection(routed), isEmpty);
  });

  test('fromMap reads metadata and tolerates its absence', () {
    final withMeta = NotificationModel.fromMap({
      'id': 'n',
      'metadata': {'order_id': 'o1'},
    });
    expect(withMeta.metadata, {'order_id': 'o1'});
    expect(NotificationModel.fromMap({'id': 'n'}).metadata, isNull);
    expect(
      NotificationModel.fromMap({'id': 'n', 'metadata': 'oops'}).metadata,
      isNull,
    );
  });
}
