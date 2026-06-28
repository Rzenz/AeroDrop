// Smoke test: verify the app boots without crashing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/app.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AeroDropApp()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProviderScope), findsOneWidget);
    // Unmount the app to dispose of infinite animations and tickers
    await tester.pumpWidget(const SizedBox());
  });
}
