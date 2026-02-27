import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboxListItemViewModel', () {
    testWidgets(
        'gracefully falls back when the stored status index is out of range',
        (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 999, // legacy/invalid value should not crash
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'aiConfigDelete',
          'id': 'config-id',
        }),
        subject: 'subject',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.statusLabel, 'Pending');
      expect(
        viewModel.statusColor,
        Theme.of(capturedContext).colorScheme.tertiary,
      );
    });

    testWidgets('trims whitespace subjects and reports missing attachment',
        (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 7,
        createdAt: DateTime(2024, 2, 2, 12),
        updatedAt: DateTime(2024, 2, 2, 12),
        status: 2,
        retries: 2,
        // malformed payload should fall back to Unknown payload
        message: '{"unexpected":"shape"}',
        subject: '   ',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.subjectValue, isNull);
      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncListUnknownPayload,
      );
      expect(viewModel.attachmentValue, 'No attachment');
      expect(viewModel.retriesLabel, '2 Retries');
      expect(
        viewModel.semanticsLabel.toLowerCase(),
        contains('unknown payload'),
      );
    });

    testWidgets('shows backfill request payload label', (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 10,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 0,
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'backfillRequest',
          'entries': [
            {'hostId': 'host-1', 'counter': 5},
          ],
          'requesterId': 'requester-1',
        }),
        subject: 'Backfill',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncPayloadBackfillRequest,
      );
    });

    testWidgets('shows backfill response payload label', (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 11,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 0,
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'backfillResponse',
          'hostId': 'host-1',
          'counter': 5,
          'deleted': true,
        }),
        subject: 'Backfill Response',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncPayloadBackfillResponse,
      );
    });
    testWidgets('shows agent entity payload label', (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 12,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 0,
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'agentEntity',
          'agentEntity': {
            'runtimeType': 'agent',
            'id': 'entity-001',
            'agentId': 'agent-001',
            'kind': 'task_agent',
            'displayName': 'Test Agent',
            'lifecycle': 'active',
            'mode': 'autonomous',
            'allowedCategoryIds': <String>[],
            'currentStateId': 'state-001',
            'config': <String, dynamic>{},
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
          'status': 'update',
        }),
        subject: 'agentEntity:entity-001',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncPayloadAgentEntity,
      );
    });

    testWidgets('shows agent link payload label', (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 13,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 0,
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'agentLink',
          'agentLink': {
            'runtimeType': 'basic',
            'id': 'link-001',
            'fromId': 'agent-001',
            'toId': 'entity-001',
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
          'status': 'update',
        }),
        subject: 'agentLink:link-001',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncPayloadAgentLink,
      );
    });

    group('payloadSizeLabel', () {
      OutboxItem makeItem({int? payloadSize}) => OutboxItem(
            id: 100,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            status: 0,
            retries: 0,
            message: jsonEncode({
              'runtimeType': 'aiConfigDelete',
              'id': 'config-id',
            }),
            subject: 'test',
            payloadSize: payloadSize,
          );

      testWidgets('is null when payloadSize is null', (tester) async {
        late OutboxListItemViewModel viewModel;

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) {
                viewModel = OutboxListItemViewModel.fromItem(
                  context: context,
                  item: makeItem(),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await tester.pump();
        expect(viewModel.payloadSizeLabel, isNull);
      });

      testWidgets('formats bytes correctly', (tester) async {
        final cases = <int, String>{
          500: '500 B',
          2048: '2.0 KB',
          1572864: '1.5 MB',
          0: '0 B',
          1023: '1023 B',
          1024: '1.0 KB',
          1048576: '1.0 MB',
          1073741824: '1.00 GB',
          1610612736: '1.50 GB',
        };

        for (final entry in cases.entries) {
          late OutboxListItemViewModel viewModel;

          await tester.pumpWidget(
            makeTestableWidgetNoScroll(
              Builder(
                builder: (context) {
                  viewModel = OutboxListItemViewModel.fromItem(
                    context: context,
                    item: makeItem(payloadSize: entry.key),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          await tester.pump();
          expect(
            viewModel.payloadSizeLabel,
            entry.value,
            reason: '${entry.key} bytes should format as ${entry.value}',
          );
        }
      });
    });
  });
}
