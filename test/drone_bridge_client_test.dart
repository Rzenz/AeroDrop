import 'dart:convert';
import 'dart:io';

import 'package:aerodrop/core/services/drone_bridge_client.dart';
import 'package:aerodrop/features/admin/send_to_drone_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBridgeAddress', () {
    test('host alone uses the default port', () {
      expect(parseBridgeAddress(' 192.168.1.100 '), ('192.168.1.100', 5005));
    });
    test('host and port', () {
      expect(parseBridgeAddress('192.168.1.100:6000'), ('192.168.1.100', 6000));
    });
    test('empty or bad port is refused', () {
      expect(parseBridgeAddress(''), isNull);
      expect(parseBridgeAddress('192.168.1.100:abc'), isNull);
      expect(parseBridgeAddress('192.168.1.100:70000'), isNull);
      expect(parseBridgeAddress(':5005'), isNull);
    });
  });

  test('bridgePayload is what aio.py parses', () {
    final p = bridgePayload(deliveryId: 'd-1', lat: 10.3, lon: 123.9, alt: 20);
    expect(p, {'delivery_id': 'd-1', 'lat': 10.3, 'lon': 123.9, 'alt': 20.0});
    expect(
      bridgePayload(deliveryId: 'd-1', lat: 1, lon: 2).containsKey('alt'),
      isFalse,
    );
  });

  test('dropoffFromFlightPlan reads the drop-off waypoint and altitude', () {
    final plan = {
      'altitude_m_agl': 20,
      'waypoints': [
        {'role': 'launch', 'latitude': 10.0, 'longitude': 123.0},
        {'role': 'dropoff', 'latitude': 10.3262, 'longitude': 123.9544},
      ],
    };
    expect(dropoffFromFlightPlan(plan), (10.3262, 123.9544, 20.0));
    expect(dropoffFromFlightPlan({'waypoints': []}), isNull);
    expect(dropoffFromFlightPlan(null), isNull);
  });

  test('sendDeliveryToBridge sends one JSON datagram and reads the reply', () async {
    // A stand-in for aio.py's UDP listener
    final server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? received;
    server.listen((e) {
      if (e != RawSocketEvent.read) return;
      final dg = server.receive();
      if (dg == null) return;
      received = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      server.send(
        utf8.encode(jsonEncode({'ok': true, 'message': 'Started: cruise 20 m'})),
        dg.address,
        dg.port,
      );
    });

    final reply = await sendDeliveryToBridge(
      address: '127.0.0.1:${server.port}',
      payload: bridgePayload(deliveryId: 'd-1', lat: 10.3, lon: 123.9, alt: 20),
    );
    server.close();

    expect(reply.ok, isTrue);
    expect(reply.message, 'Started: cruise 20 m');
    expect(received?['delivery_id'], 'd-1');
  });

  test('no bridge listening gives a clear timeout message', () async {
    final unused = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = unused.port;
    unused.close();
    final reply = await sendDeliveryToBridge(
      address: '127.0.0.1:$port',
      payload: bridgePayload(deliveryId: 'd-1', lat: 1, lon: 2),
      timeout: const Duration(milliseconds: 300),
    );
    expect(reply.ok, isFalse);
    expect(reply.message, anyOf(contains('No answer'), contains('Cannot reach')));
  });
}
