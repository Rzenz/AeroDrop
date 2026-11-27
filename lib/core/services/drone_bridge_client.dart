// Sends a delivery to the ground-station bridge (python_script/aio.py) on the
// operator's laptop, which flies it through Mission Planner.
//
// The command is one UDP datagram of JSON:
//   {"delivery_id": "...", "lat": 10.3, "lon": 123.9, "alt": 20}
// and the bridge answers with {"ok": true|false, "message": "..."}. The phone
// and the laptop must be on the same Wi-Fi. A browser cannot send UDP, so on
// the web build sendDeliveryToBridge always fails with a clear message.
import 'package:shared_preferences/shared_preferences.dart';

import 'drone_bridge_io.dart'
    if (dart.library.js_interop) 'drone_bridge_web.dart'
    as transport;

const int droneBridgeDefaultPort = 5005;
const String _hostKey = 'drone_bridge_host';

class BridgeReply {
  final bool ok;
  final String message;
  const BridgeReply(this.ok, this.message);
}

/// "192.168.1.100" or "192.168.1.100:5005"; empty until the admin sets it.
Future<String> loadBridgeAddress() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_hostKey) ?? '';
}

Future<void> saveBridgeAddress(String address) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_hostKey, address.trim());
}

/// Splits "host[:port]". Returns null when the host is empty or the port is
/// not a number from 1 to 65535.
(String, int)? parseBridgeAddress(String address) {
  final a = address.trim();
  if (a.isEmpty) return null;
  final i = a.lastIndexOf(':');
  if (i < 0) return (a, droneBridgeDefaultPort);
  final host = a.substring(0, i).trim();
  final port = int.tryParse(a.substring(i + 1).trim());
  if (host.isEmpty || port == null || port < 1 || port > 65535) return null;
  return (host, port);
}

/// The datagram the bridge expects.
Map<String, Object?> bridgePayload({
  required String deliveryId,
  required double lat,
  required double lon,
  double? alt,
}) => {
  'delivery_id': deliveryId,
  'lat': lat,
  'lon': lon,
  'alt': ?alt,
};

Future<BridgeReply> sendDeliveryToBridge({
  required String address,
  required Map<String, Object?> payload,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final parsed = parseBridgeAddress(address);
  if (parsed == null) {
    return const BridgeReply(
      false,
      'Set the ground station address first, e.g. 192.168.1.100',
    );
  }
  return transport.sendUdp(parsed.$1, parsed.$2, payload, timeout);
}
