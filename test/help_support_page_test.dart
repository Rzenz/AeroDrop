import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/support_report_model.dart';
import 'package:aerodrop/core/providers/support_chat_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/shared/help_support_page.dart';

const _long =
    'An extraordinarily long subject line that must ellipsize cleanly at 360dp';

SupportReportModel _report(String id, String status, {int unread = 0}) =>
    SupportReportModel(
      id: id,
      userId: 'me',
      subject: _long,
      message: 'Details',
      category: 'delivery_issue',
      status: status,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: unread,
    );

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Future<List<SupportReportModel>> Function() reports,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AppTheme.isDarkMode = true;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mySupportReportsProvider.overrideWith((ref) => reports())],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HelpSupportPage(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

  for (final entry in sizes.entries) {
    group('help & support — ${entry.key}', () {
      testWidgets('no reports yet', (tester) async {
        await _pump(tester, entry.value, () async => const []);
        expect(tester.takeException(), isNull);
        expect(find.text('New Report'), findsOneWidget);
        expect(find.textContaining('No reports yet'), findsOneWidget);
        // The form stays closed until asked for
        expect(find.text('Submit Report'), findsNothing);
        await _unmount(tester);
      });

      testWidgets('a list of reports, then the form', (tester) async {
        await _pump(
          tester,
          entry.value,
          () async => [
            _report('r1', 'open', unread: 2),
            _report('r2', 'resolved'),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(_long), findsNWidgets(2));
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Resolved'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.text('New Report'));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Submit a Support Request'), findsOneWidget);
        expect(find.text('Submit Report'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('reports fail to load', (tester) async {
        await _pump(tester, entry.value, () async => throw Exception('down'));
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Could not load your reports'),
          findsOneWidget,
        );
        await _unmount(tester);
      });
    });
  }
}
