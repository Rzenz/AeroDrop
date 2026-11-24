// Display text for drone telemetry read straight from the database.
//
// The columns are numeric, so a value such as 82.39000228571429 arrives with
// every digit the flight computation produced. These helpers give the same
// precision the live tracking card already uses: whole percentages, and one
// decimal for speed (m/s, as the flight code records it) and altitude.

double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

/// "82%", or "—" when there is no reading.
String formatPercent(Object? v) {
  final n = _num(v);
  return n == null ? '—' : '${n.round()}%';
}

/// "4.2 m/s", or "—" when there is no reading.
String formatSpeed(Object? v) {
  final n = _num(v);
  return n == null ? '—' : '${n.toStringAsFixed(1)} m/s';
}

/// "15.0 m", or "—" when there is no reading.
String formatAltitude(Object? v) {
  final n = _num(v);
  return n == null ? '—' : '${n.toStringAsFixed(1)} m';
}

/// "90°", or "—" when there is no reading.
String formatHeading(Object? v) {
  final n = _num(v);
  return n == null ? '—' : '${n.round()}°';
}
