import 'dart:convert';
import 'dart:io';

Future<void> sendTargetToDrone(double lat, double lon, double alt) async {
  final payload = jsonEncode({
    'lat': lat,
    'lon': lon,
    'alt': alt,
  });

  // Send via UDP to Python bridge
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.send(
    utf8.encode(payload),
    InternetAddress('192.168.1.100'), // Replace with your PC's IP (or 127.0.0.1 if on same PC)
    5005,
  );
  socket.close();
}
