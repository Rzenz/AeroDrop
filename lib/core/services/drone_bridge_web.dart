import 'drone_bridge_client.dart';

/// Browsers cannot send UDP.
Future<BridgeReply> sendUdp(
  String host,
  int port,
  Map<String, Object?> payload,
  Duration timeout,
) async => const BridgeReply(
  false,
  'A browser cannot reach the ground station. Send the delivery from the '
  'AeroDrop app on a phone or laptop on the same Wi-Fi.',
);
