import 'package:aerodrop/core/utils/telemetry_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telemetry readings from the database are shown rounded', () {
    expect(formatPercent(82.39000228571429), '82%');
    expect(formatPercent('99.6'), '100%');
    expect(formatSpeed(4.2400001), '4.2 m/s');
    expect(formatAltitude(15), '15.0 m');
    expect(formatHeading(89.7), '90°');
    expect(formatPercent(null), '—');
  });
}
