// Smoke test: verify the app boots without crashing.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/app.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AeroDropApp()));
    // Just boot — no counter in this app.
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
