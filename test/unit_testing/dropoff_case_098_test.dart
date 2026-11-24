import 'package:aerodrop/core/providers/delivery_zone_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/core/widgets/neu_button.dart';
import 'package:aerodrop/features/cart/dropoff_map_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _zone = DeliveryZone(
  centerLatitude: 10.325152,
  centerLongitude: 123.953046,
  centerName: 'Campus Drone Hub',
  radiusMeters: 300,
);

void main() {
  group('Test Case ID: CASE-098', () {
    testWidgets(
      'Test Case Description: Customer places a custom drop-off pin about 450 m from the Campus Drone Hub (limit 300 m) | '
      'Expected Result: The pin is marked outside the delivery area and Confirm drop-off stays disabled',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        AppTheme.isDarkMode = true;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: const DropoffMapPicker(zone: _zone, initial: (lat: 10.329194, lng: 123.953046, label: null)),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('Outside the delivery area'), findsOneWidget);
        expect(find.textContaining('the limit is 300 m'), findsOneWidget);
        expect(tester.widget<NeuButton>(find.byType(NeuButton)).onPressed, isNull);
      },
    );
  });
}
