import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aerodrop/core/models/support_message_model.dart';
import 'package:aerodrop/core/models/support_report_model.dart';
import 'package:aerodrop/core/providers/notification_provider.dart';
import 'package:aerodrop/core/providers/support_chat_provider.dart';
import 'package:aerodrop/core/theme/app_theme.dart';
import 'package:aerodrop/features/support/support_thread_screen.dart';

const _reportId = '11111111-2222-4333-8444-555555555555';
const _long =
    'An extraordinarily long subject line that must ellipsize cleanly at 360dp';

SupportMessageModel _msg(
  String id,
  DateTime at, {
  String sender = 'admin-1',
  String text = 'Hello',
  List<String> attachments = const [],
}) => SupportMessageModel(
  id: id,
  reportId: _reportId,
  senderId: sender,
  message: text,
  attachments: attachments,
  createdAt: at,
);

SupportReportModel _report({String status = 'open'}) => SupportReportModel(
  id: _reportId,
  userId: 'reporter-1',
  subject: _long,
  message: 'My drone delivery arrived with a crushed box. ' * 6,
  category: 'delivery_issue',
  status: status,
  createdAt: DateTime(2026, 11, 1, 9, 30),
);

/// Stands in for the real notifier with fixed messages. Signing always fails,
/// so attachments show their failure state without touching storage.
class _FakeChat extends SupportChatNotifier {
  _FakeChat(List<SupportMessageModel> messages) : super(_reportId) {
    state = SupportChatState(messages: messages, isLoading: false);
  }

  @override
  Future<String> signedUrlFor(String path) => Future.error('no storage');

  @override
  Future<void> markRead() async {}
}

void main() {
  group('SupportMessageModel.fromMap', () {
    test('reads attachments and tolerates missing or odd values', () {
      final m = SupportMessageModel.fromMap({
        'id': 'm1',
        'report_id': _reportId,
        'sender_id': 'u1',
        'message': '',
        'attachments': ['$_reportId/a.jpg', null, ''],
        'created_at': '2026-11-01T01:00:00Z',
      });
      expect(m.attachments, ['$_reportId/a.jpg']);
      expect(m.message, '');
      expect(m.readAt, isNull);

      expect(SupportMessageModel.fromMap({'id': 'm2'}).attachments, isEmpty);
      expect(
        SupportMessageModel.fromMap({
          'id': 'm3',
          'attachments': 'x',
        }).attachments,
        isEmpty,
      );
    });
  });

  group('SupportReportModel.fromMap', () {
    test('derives last activity and unread from embedded replies', () {
      final r = SupportReportModel.fromMap({
        'id': _reportId,
        'user_id': 'me',
        'subject': 'Box crushed',
        'status': 'resolved',
        'created_at': '2026-11-01T00:00:00Z',
        'support_messages': [
          {
            'created_at': '2026-11-02T00:00:00Z',
            'sender_id': 'admin',
            'read_at': null,
          },
          {
            'created_at': '2026-11-03T00:00:00Z',
            'sender_id': 'admin',
            'read_at': '2026-11-03T01:00:00Z',
          },
          {
            'created_at': '2026-11-04T00:00:00Z',
            'sender_id': 'me',
            'read_at': null,
          },
        ],
      }, currentUserId: 'me');

      expect(r.isResolved, isTrue);
      expect(r.unreadCount, 1);
      expect(
        r.lastActivityAt,
        DateTime.parse('2026-11-04T00:00:00Z').toLocal(),
      );
      expect(r.categoryLabel, 'General Inquiries');
    });

    test('without replies, last activity is the report itself', () {
      final r = SupportReportModel.fromMap({
        'id': _reportId,
        'created_at': '2026-11-01T00:00:00Z',
      });
      expect(r.status, 'open');
      expect(r.unreadCount, 0);
      expect(r.lastActivityAt, r.createdAt);
    });
  });

  test('mergeSorted drops the realtime copy of a sent message', () {
    final a = _msg('a', DateTime(2026, 11, 1, 10));
    final b = _msg('b', DateTime(2026, 11, 1, 9));
    final merged = SupportChatNotifier.mergeSorted([a], [b, a]);
    expect(merged.map((m) => m.id), ['b', 'a']);
  });

  group('sendMessage checks locally before any network call', () {
    XFile img() => XFile.fromData(Uint8List.fromList([0xFF, 0xD8, 0xFF]));

    test('more than three photos', () async {
      final chat = SupportChatNotifier(_reportId);
      addTearDown(chat.dispose);
      expect(
        () => chat.sendMessage('hi', [img(), img(), img(), img()]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('no text and no photos', () async {
      final chat = SupportChatNotifier(_reportId);
      addTearDown(chat.dispose);
      expect(
        () => chat.sendMessage('   ', const []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('text over the limit', () async {
      final chat = SupportChatNotifier(_reportId);
      addTearDown(chat.dispose);
      expect(
        () => chat.sendMessage('x' * (kSupportMessageMaxLength + 1), const []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('timestamps match the order chat format', () {
    final now = DateTime(2026, 11, 8, 15);
    expect(
      formatSupportTimestamp(DateTime(2026, 11, 8, 9, 5), now: now),
      '09:05',
    );
    expect(
      formatSupportTimestamp(DateTime(2026, 3, 2, 9, 5), now: now),
      '3/2 09:05',
    );
    expect(
      formatSupportTimestamp(DateTime(2025, 3, 2, 9, 5), now: now),
      '3/2/2025 09:05',
    );
  });

  const sizes = {'360dp': Size(360, 740), 'desktop': Size(1366, 768)};

  Future<void> pump(
    WidgetTester tester,
    Size size,
    List<Override> overrides,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    AppTheme.isDarkMode = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadNotificationCountProvider.overrideWithValue(0),
          supportUserNameProvider.overrideWith((ref, id) async => _long),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SupportThreadScreen(reportId: _reportId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final entry in sizes.entries) {
    group('support thread — ${entry.key}', () {
      testWidgets('resolved report with replies and photos', (tester) async {
        await pump(tester, entry.value, [
          supportReportProvider.overrideWith(
            (ref, id) async => _report(status: 'resolved'),
          ),
          supportChatProvider.overrideWith(
            (ref, id) => _FakeChat([
              _msg(
                '1',
                DateTime(2026, 11, 1, 10),
                text: 'Can you send a photo?',
              ),
              _msg(
                '2',
                DateTime(2026, 11, 1, 11),
                sender: 'reporter-1',
                text: 'Here it is. ' * 30,
                attachments: ['$_reportId/a.jpg', '$_reportId/b.png'],
              ),
              _msg(
                '3',
                DateTime(2026, 11, 1, 12),
                sender: 'reporter-1',
                text: '',
                attachments: ['$_reportId/c.webp'],
              ),
            ]),
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        // An admin is told their reply will not reopen the report
        expect(
          find.text('This report is resolved. Your reply will not reopen it.'),
          findsOneWidget,
        );
        // Composer stays usable on a resolved report
        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
        // Newest first on screen: the photo-only reply, whose failed signing
        // shows the failure state
        expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);

        // The admin's reply is older; scroll up to it
        final thread = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Support'),
          300,
          scrollable: thread,
        );
        expect(find.text('Support'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('no replies yet shows the original report', (tester) async {
        await pump(tester, entry.value, [
          supportReportProvider.overrideWith((ref, id) async => _report()),
          supportChatProvider.overrideWith((ref, id) => _FakeChat(const [])),
        ]);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Original report'), findsOneWidget);
        expect(find.text('No replies yet.'), findsOneWidget);
        expect(find.textContaining('resolved'), findsNothing);
      });

      testWidgets('a report the user cannot see', (tester) async {
        await pump(tester, entry.value, [
          supportReportProvider.overrideWith((ref, id) async => null),
          supportChatProvider.overrideWith((ref, id) => _FakeChat(const [])),
        ]);

        expect(tester.takeException(), isNull);
        expect(find.text('Report not found'), findsOneWidget);
      });
    });
  }
}
