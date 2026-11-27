import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'drone_bridge_client.dart';

/// One datagram out, then wait for the bridge's one-line JSON answer.
Future<BridgeReply> sendUdp(
  String host,
  int port,
  Map<String, Object?> payload,
  Duration timeout,
) async {
  RawDatagramSocket? socket;
  try {
    final addresses = await InternetAddress.lookup(host);
    final target = addresses.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final reply = Completer<BridgeReply>();
    socket.listen((event) {
      if (event != RawSocketEvent.read || reply.isCompleted) return;
      final dg = socket!.receive();
      if (dg == null) return;
      reply.complete(_decode(utf8.decode(dg.data, allowMalformed: true)));
    });
    socket.send(utf8.encode(jsonEncode(payload)), target, port);
    return await reply.future.timeout(
      timeout,
      onTimeout: () => BridgeReply(
        false,
        'No answer from the ground station at $host:$port. Check that aio.py '
        'is running and the phone is on the same Wi-Fi.',
      ),
    );
  } on SocketException catch (e) {
    return BridgeReply(false, 'Cannot reach $host:$port (${e.message})');
  } finally {
    socket?.close();
  }
}

BridgeReply _decode(String text) {
  try {
    final j = jsonDecode(text);
    if (j is Map) {
      return BridgeReply(j['ok'] == true, '${j['message'] ?? ''}');
    }
  } catch (_) {}
  return BridgeReply(false, text.trim());
}
