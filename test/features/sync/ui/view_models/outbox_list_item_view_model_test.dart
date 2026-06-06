import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/features/sync/vector_clock.dart';
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
          priority: OutboxPriority.low.index,
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
      },
    );

    testWidgets('trims whitespace subjects and reports missing attachment', (
      tester,
    ) async {
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
        priority: OutboxPriority.low.index,
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

    // The payload-kind label cases share one shape: encode a sync-message
    // JSON into an OutboxItem, build the view model, and compare the label
    // against the localized string. One spec per message kind.
    Future<({OutboxListItemViewModel viewModel, BuildContext context})>
    pumpPayloadItem(WidgetTester tester, OutboxItem item) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;
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
      return (viewModel: viewModel, context: capturedContext);
    }

    OutboxItem payloadItem({
      required int id,
      required Map<String, dynamic> message,
      required String subject,
      OutboxPriority priority = OutboxPriority.low,
    }) => OutboxItem(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      status: 0,
      retries: 0,
      priority: priority.index,
      message: jsonEncode(message),
      subject: subject,
    );

    final payloadKindCases =
        <
          ({
            String name,
            OutboxItem item,
            String Function(BuildContext ctx) expectedLabel,
          })
        >[
          (
            name: 'backfill request',
            item: payloadItem(
              id: 10,
              message: {
                'runtimeType': 'backfillRequest',
                'entries': [
                  {'hostId': 'host-1', 'counter': 5},
                ],
                'requesterId': 'requester-1',
              },
              subject: 'Backfill',
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadBackfillRequest,
          ),
          (
            name: 'backfill response',
            item: payloadItem(
              id: 11,
              message: {
                'runtimeType': 'backfillResponse',
                'hostId': 'host-1',
                'counter': 5,
                'deleted': true,
              },
              subject: 'Backfill Response',
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadBackfillResponse,
          ),
          (
            name: 'agent entity',
            item: payloadItem(
              id: 12,
              message: {
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
              },
              subject: 'agentEntity:entity-001',
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadAgentEntity,
          ),
          (
            name: 'agent link',
            item: payloadItem(
              id: 13,
              message: {
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
              },
              subject: 'agentLink:link-001',
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadAgentLink,
          ),
          (
            name: 'notification',
            item: payloadItem(
              id: 30,
              message: {
                'runtimeType': 'notification',
                'id': 'notification-id',
                'jsonPath': '/notifications/notification-id.json',
                'vectorClock': {'host-1': 1},
                'originatingHostId': 'host-1',
              },
              subject: 'notification:notification-id',
              priority: OutboxPriority.normal,
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadNotification,
          ),
          (
            name: 'notification state update',
            item: payloadItem(
              id: 31,
              message: {
                'runtimeType': 'notificationStateUpdate',
                'id': 'notification-id',
                'vectorClock': {'host-1': 2},
                'originatingHostId': 'host-1',
              },
              subject: 'notificationStateUpdate:notification-id',
              priority: OutboxPriority.normal,
            ),
            expectedLabel: (ctx) =>
                ctx.messages.syncPayloadNotificationStateUpdate,
          ),
          (
            name: 'agent bundle',
            item: payloadItem(
              id: 14,
              message: {
                'runtimeType': 'agentBundle',
                'agentId': 'agent-001',
                'wakeRunKey': 'run-001',
                'entities': <Object?>[],
                'links': <Object?>[],
                'jsonPath': '/agent_bundles/run-001.json',
              },
              subject: 'agentBundle:agent-001:run-001',
            ),
            expectedLabel: (ctx) => ctx.messages.syncPayloadAgentBundle,
          ),
        ];

    for (final c in payloadKindCases) {
      testWidgets('shows ${c.name} payload label', (tester) async {
        final result = await pumpPayloadItem(tester, c.item);
        expect(
          result.viewModel.payloadKindLabel,
          c.expectedLabel(result.context),
        );
      });
    }

    // Two bundle-count cases share the same widget setup. The behaviour
    // under test is purely the count-formatting in the view model, so the
    // permutations live in one parameterized loop instead of two
    // copy-pasted bodies. (Empty bundle is the defensive case: in
    // production the sender skips empty bundles, but the UI must still
    // render a sensible label if one ever lands in the outbox.)
    Future<({OutboxListItemViewModel viewModel, BuildContext context})>
    pumpOutboxBundle(WidgetTester tester, OutboxItem item) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;
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
      return (viewModel: viewModel, context: capturedContext);
    }

    final outboxBundleCases = <({int childCount, int rowId, String pathId})>[
      (childCount: 3, rowId: 15, pathId: 'abc-123'),
      (childCount: 0, rowId: 16, pathId: 'empty'),
    ];

    for (final c in outboxBundleCases) {
      testWidgets(
        'outbox bundle label shows child count (${c.childCount})',
        (tester) async {
          final children = List<Map<String, Object?>>.generate(
            c.childCount,
            (i) => {'runtimeType': 'aiConfigDelete', 'id': 'cfg-${i + 1}'},
          );
          final item = OutboxItem(
            id: c.rowId,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            status: 0,
            retries: 0,
            priority: OutboxPriority.normal.index,
            message: jsonEncode({
              'runtimeType': 'outboxBundle',
              'children': children,
              'jsonPath': '/outbox_bundles/${c.pathId}.json',
            }),
            subject: 'outboxBundle:${c.pathId}',
          );

          final setup = await pumpOutboxBundle(tester, item);

          expect(
            setup.viewModel.payloadKindLabel,
            '${setup.context.messages.syncPayloadOutboxBundle} '
            '(${c.childCount})',
          );
        },
      );
    }

    // OutboxStatus.sending (index=3) has its own icon/chipIcon/color branches
    // that were not exercised by any existing test.  All four switch arms land
    // in this single parameterised loop so no copy-paste permutations are needed.
    group('OutboxStatus.sending status fields', () {
      testWidgets(
        'sending status maps to tertiary color, sync icons, and Pending label',
        (tester) async {
          late OutboxListItemViewModel viewModel;
          late BuildContext capturedContext;

          final item = OutboxItem(
            id: 200,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            status: OutboxStatus.sending.index, // index 3
            retries: 0,
            message: jsonEncode({
              'runtimeType': 'aiConfigDelete',
              'id': 'cfg-send',
            }),
            subject: 'sending-subject',
            priority: OutboxPriority.low.index,
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

          // statusLabel: sending maps to the "pending" localized string
          expect(viewModel.statusLabel, 'Pending');
          // statusColor: sending → tertiary (same as pending)
          expect(
            viewModel.statusColor,
            Theme.of(capturedContext).colorScheme.tertiary,
          );
          // statusIcon: sending → Icons.sync_rounded
          expect(viewModel.statusIcon, Icons.sync_rounded);
          // statusChipIcon: sending → Icons.sync_rounded
          expect(viewModel.statusChipIcon, Icons.sync_rounded);
        },
      );
    });

    group('_payloadKindLabel non-map JSON', () {
      testWidgets(
        'returns unknown payload label when message is a JSON array',
        (tester) async {
          late OutboxListItemViewModel viewModel;
          late BuildContext capturedContext;

          // A top-level JSON array is valid JSON but is not a Map → line 149
          final item = OutboxItem(
            id: 201,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            status: OutboxStatus.pending.index,
            retries: 0,
            message: jsonEncode(['not', 'a', 'map']),
            subject: 'array-subject',
            priority: OutboxPriority.low.index,
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
            capturedContext.messages.syncListUnknownPayload,
          );
        },
      );
    });

    // Lines 153-156, 158, 172: payload-kind label branches for the four
    // SyncMessage variants that were not yet covered.  A single loop avoids
    // copy-paste and keeps the intent clear.
    group('_payloadKindLabel remaining sync message variants', () {
      // Helper shared by all cases in this group.
      Future<({OutboxListItemViewModel viewModel, BuildContext ctx})>
      pumpWithMessage(
        WidgetTester tester,
        int rowId,
        String encodedMessage,
      ) async {
        late OutboxListItemViewModel viewModel;
        late BuildContext ctx;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Builder(
              builder: (context) {
                ctx = context;
                viewModel = OutboxListItemViewModel.fromItem(
                  context: context,
                  item: OutboxItem(
                    id: rowId,
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    status: OutboxStatus.pending.index,
                    retries: 0,
                    message: encodedMessage,
                    subject: 'test-subject',
                    priority: OutboxPriority.low.index,
                  ),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
        return (viewModel: viewModel, ctx: ctx);
      }

      testWidgets('journalEntity payload label (line 153)', (tester) async {
        const msg = SyncMessage.journalEntity(
          id: 'je-001',
          jsonPath: '/entries/je-001.json',
          vectorClock: VectorClock({'host-1': 1}),
          status: SyncEntryStatus.update,
        );
        final result = await pumpWithMessage(
          tester,
          300,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadJournalEntity,
        );
      });

      testWidgets('entityDefinition payload label (line 154)', (tester) async {
        final msg = SyncMessage.entityDefinition(
          entityDefinition: EntityDefinition.measurableDataType(
            id: 'mdt-001',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            displayName: 'Weight',
            description: 'Body weight in kg',
            unitName: 'kg',
            version: 1,
            vectorClock: null,
          ),
          status: SyncEntryStatus.update,
        );
        final result = await pumpWithMessage(
          tester,
          301,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadEntityDefinition,
        );
      });

      testWidgets('entryLink payload label (line 155)', (tester) async {
        final msg = SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-001',
            fromId: 'from-001',
            toId: 'to-001',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          status: SyncEntryStatus.update,
        );
        final result = await pumpWithMessage(
          tester,
          302,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadEntryLink,
        );
      });

      testWidgets('aiConfig payload label (line 156)', (tester) async {
        final msg = SyncMessage.aiConfig(
          aiConfig: AiConfig.inferenceProvider(
            id: 'provider-001',
            name: 'Test Provider',
            apiKey: 'key-abc',
            baseUrl: 'https://api.example.invalid/v1',
            createdAt: DateTime(2024, 3, 15),
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          ),
          status: SyncEntryStatus.update,
        );
        final result = await pumpWithMessage(
          tester,
          303,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadAiConfig,
        );
      });

      testWidgets('configFlag payload label', (tester) async {
        const msg = SyncMessage.configFlag(
          name: 'enable_logging',
          description: 'Enable logging',
          status: true,
        );
        final result = await pumpWithMessage(
          tester,
          306,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadConfigFlag,
        );
      });

      testWidgets('themingSelection payload label (line 158)', (tester) async {
        const msg = SyncMessage.themingSelection(
          lightThemeName: 'Indigo',
          darkThemeName: 'Shark',
          themeMode: 'dark',
          updatedAt: 1234567890,
          status: SyncEntryStatus.update,
        );
        final result = await pumpWithMessage(
          tester,
          304,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadThemingSelection,
        );
      });

      testWidgets('syncNodeProfile payload label (line 172)', (tester) async {
        final msg = SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-profile-001',
            displayName: 'Test Node',
            platform: 'macos',
            capabilities: const [NodeCapability.mlxAudio],
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final result = await pumpWithMessage(
          tester,
          305,
          jsonEncode(msg.toJson()),
        );
        expect(
          result.viewModel.payloadKindLabel,
          result.ctx.messages.syncPayloadSyncNodeProfile,
        );
      });
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
        priority: OutboxPriority.low.index,
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

  group('OutboxListItemViewModel.formatBytes — properties', () {
    test('null in, null out', () {
      expect(OutboxListItemViewModel.formatBytes(null), isNull);
    });

    glados.Glados<int>(
      glados.any.intInRange(0, 1024),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'values below 1 KiB render as whole bytes',
      (bytes) {
        expect(OutboxListItemViewModel.formatBytes(bytes), '$bytes B');
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(1024, 1024 * 1024),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'KiB range renders one decimal and round-trips within rounding error',
      (bytes) {
        final label = OutboxListItemViewModel.formatBytes(bytes)!;
        expect(label, endsWith(' KB'));
        final value = double.parse(label.split(' ').first);
        expect(value, closeTo(bytes / 1024, 0.051));
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(1024 * 1024, 1024 * 1024 * 1024),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'MiB range renders one decimal and round-trips within rounding error',
      (bytes) {
        final label = OutboxListItemViewModel.formatBytes(bytes)!;
        expect(label, endsWith(' MB'));
        final value = double.parse(label.split(' ').first);
        expect(value, closeTo(bytes / (1024 * 1024), 0.051));
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(1024 * 1024 * 1024, 64 * 1024 * 1024 * 1024),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'GiB range renders two decimals and round-trips within rounding error',
      (bytes) {
        final label = OutboxListItemViewModel.formatBytes(bytes)!;
        expect(label, endsWith(' GB'));
        final value = double.parse(label.split(' ').first);
        expect(value, closeTo(bytes / (1024 * 1024 * 1024), 0.0051));
      },
      tags: 'glados',
    );
  });
}
