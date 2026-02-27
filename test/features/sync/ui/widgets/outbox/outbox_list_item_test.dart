import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_list_item.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OutboxItem makeItem({
    int? payloadSize,
    int status = 0,
    String? filePath,
  }) =>
      OutboxItem(
        id: 42,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        status: status,
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'aiConfigDelete',
          'id': 'config-id',
        }),
        subject: 'test-subject',
        filePath: filePath,
        payloadSize: payloadSize,
      );

  group('OutboxListItem', () {
    testWidgets('shows payload size row when payloadSize is set',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(item: makeItem(payloadSize: 2048)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2.0 KB'), findsOneWidget);
      expect(find.byIcon(Icons.data_usage_rounded), findsOneWidget);
    });

    testWidgets('hides payload size row when payloadSize is null',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(item: makeItem()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.data_usage_rounded), findsNothing);
    });

    testWidgets('displays localized size label', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return OutboxListItem(
                  item: makeItem(payloadSize: 1048576),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizeLabel = capturedContext.messages.outboxMonitorPayloadSizeLabel;
      expect(find.textContaining(sizeLabel), findsOneWidget);
      expect(find.textContaining('1.0 MB'), findsOneWidget);
    });

    testWidgets('shows status icon and chips for pending item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(
                payloadSize: 500,
                status: OutboxStatus.pending.index,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.textContaining('500 B'), findsOneWidget);
    });

    testWidgets('shows status icon for sent item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(
                payloadSize: 3072,
                status: OutboxStatus.sent.index,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.check_circle_outline_rounded),
        findsOneWidget,
      );
      expect(find.textContaining('3.0 KB'), findsOneWidget);
    });

    testWidgets('shows retry button when showRetry is true', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(payloadSize: 100),
              showRetry: true,
              onRetry: () async {
                retryCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryButton = find.byIcon(Icons.replay_rounded);
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();
      expect(retryCalled, isTrue);
    });

    testWidgets('shows delete button when showDelete is true', (tester) async {
      var deleteCalled = false;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(payloadSize: 100),
              showDelete: true,
              onDelete: () async {
                deleteCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    testWidgets('shows attachment path when filePath is set', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(
                payloadSize: 4096,
                filePath: '/images/photo.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('/images/photo.jpg'), findsOneWidget);
      expect(find.byIcon(Icons.attachment_rounded), findsOneWidget);
    });

    testWidgets('shows subject when subject is non-empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(item: makeItem(payloadSize: 256)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('test-subject'), findsOneWidget);
    });

    testWidgets('has correct semantics label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: OutboxListItem(
              item: makeItem(
                status: OutboxStatus.sent.index,
                payloadSize: 1024,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(OutboxListItem));
      expect(semantics.label, contains('ent'));
    });
  });
}
