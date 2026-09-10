import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_chat_pane.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../query/query_test_utils.dart';
import '../../test_data/entity_factories.dart';
import '../evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
  const key = (agentId: 'agent', scope: scope);
  late QueryTestBench bench;
  late MockQueryChatStore store;
  late List<AgentQueryChatEventEntity> events;
  late StreamController<QueryChatData> data;
  late StreamController<bool> privacy;
  late TranscriptEmittingController recorder;
  var inferenceCalls = 0;
  final identity = makeTestIdentity(
    id: 'agent',
    agentId: 'agent',
    displayName: 'Habitat Watcher',
  );

  AgentQueryChatEventEntity event(
    String id,
    String chat,
    QueryChatEventData value,
  ) => AgentQueryChatEventEntity(
    id: id,
    agentId: 'agent',
    chatId: chat,
    data: value,
    createdAt: DateTime(2026, 7, 17, 10),
    vectorClock: null,
  );
  QueryChatData snapshot({bool showPrivate = false}) => QueryChatData(
    projection: QueryChatProjection(events),
    access: QueryAccessSnapshot(
      showPrivate: showPrivate,
      categories: {for (final c in bench.categories) c.id: c},
      entries: {...bench.entries},
    ),
  );
  setUp(() {
    bench = QueryTestBench();
    bench.entries['task'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'task',
        categoryId: categoryMindfulness.id,
      ),
    );
    store = MockQueryChatStore();
    recorder = TranscriptEmittingController();
    events = [
      event(
        'first',
        'feeder',
        const QueryChatEventData.created(
          scope: scope,
          title: 'Feeder calibration',
        ),
      ),
      event(
        'second',
        'roll-call',
        const QueryChatEventData.created(scope: scope, title: 'Roll call'),
      ),
    ];
    data = StreamController<QueryChatData>.broadcast();
    privacy = StreamController<bool>.broadcast();
    inferenceCalls = 0;
    when(() => store.markRead(any(), any(), any())).thenAnswer((_) async {});
    when(
      () => store.delete(any(), any(), forget: any(named: 'forget')),
    ).thenAnswer((call) async {
      events.add(
        event(
          'deleted',
          call.positionalArguments[1] as String,
          QueryChatEventData.deleted(
            forget: call.namedArguments[#forget] as bool,
          ),
        ),
      );
      data.add(snapshot());
    });
    when(
      () => store.archive(any(), any(), archived: any(named: 'archived')),
    ).thenAnswer((call) async {
      events.add(
        event(
          'archive',
          call.positionalArguments[1] as String,
          QueryChatEventData.archived(
            archived: call.namedArguments[#archived] as bool,
          ),
        ),
      );
      data.add(snapshot());
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() async {
    await data.close();
    await privacy.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        QueryChatPane(scope: scope, onClose: () {}),
        overrides: [
          queryChatTargetProvider(scope).overrideWith(
            (ref) async => QueryChatTarget(
              scope: scope,
              label: 'Inspect orbital penguin habitat',
              agent: identity,
              categoryId: categoryMindfulness.id,
              categoryLabel: categoryMindfulness.name,
            ),
          ),
          queryChatStoreProvider.overrideWithValue(store),
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          queryChatDataProvider(key).overrideWith((ref) async* {
            yield snapshot();
            yield* data.stream;
          }),
          configFlagProvider('private').overrideWith((ref) async* {
            yield false;
            yield* privacy.stream;
          }),
          chatRecorderControllerProvider.overrideWith(() => recorder),
          queryBuilderFactoryProvider.overrideWithValue((
            scope,
            agentId,
            chatId,
          ) async {
            inferenceCalls++;
            throw const QueryInferenceUnavailable();
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> switcher(WidgetTester tester) async {
    await tester.tap(find.byIcon(LottiIcons.chevronDown).first);
    await tester.pump();
  }

  testWidgets('switching conversations preserves independent editable drafts', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Which feeder?');
    await switcher(tester);
    await tester.tap(find.text('Roll call').last);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField), 'Who attended?');
    await switcher(tester);
    await tester.tap(find.text('Feeder calibration').last);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Which feeder?',
    );
    expect(inferenceCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'dictation stays editable until Send and missing inference retains it',
    (tester) async {
      await pump(tester);
      recorder.emitTranscript('Check the feeder decision.');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Check the feeder decision.',
      );
      expect(inferenceCalls, 0);
      expect(
        find.textContaining('Nothing is sent until you press Send'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(LottiIcons.send));
      await tester.pump();
      expect(inferenceCalls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Check the feeder decision.',
      );
      expect(find.textContaining('No usable inference setup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final forget in [false, true]) {
    testWidgets(
      'delete confirms the keep/forget choice ($forget), while Cancel changes nothing',
      (tester) async {
        await pump(tester);
        Future<void> openDelete() async {
          await switcher(tester);
          await tester.tap(find.byIcon(LottiIcons.more).first);
          await tester.pump();
          await tester.tap(find.text('Delete chat'));
          await tester.pumpAndSettle();
        }

        await openDelete();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        verifyNever(
          () => store.delete(any(), any(), forget: any(named: 'forget')),
        );
        await openDelete();
        if (forget) {
          await tester.tap(find.text('Forget conclusions'));
          await tester.pump();
        }
        await tester.tap(find.text('Delete chat').last);
        await tester.pumpAndSettle();
        verify(() => store.delete('agent', 'feeder', forget: forget)).called(1);
        expect(find.text('Roll call'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'a newly private source hides its chat title, answer and preview',
    (tester) async {
      bench.add('meeting', category: categoryMindfulness.id);
      const source = QuerySourceRef(
        id: 'meeting',
        private: false,
        categoryPrivate: false,
      );
      events.add(
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'q',
            text: 'Secret feeder decision',
            coverage: QueryCoverage(),
            dependencies: [source],
          ),
        ),
      );
      await pump(tester);
      expect(find.text('Secret feeder decision'), findsOneWidget);
      bench.add('meeting', category: categoryMindfulness.id, private: true);
      data.add(snapshot());
      await tester.pump();
      await tester.pump();
      expect(find.text('Secret feeder decision'), findsNothing);
      await switcher(tester);
      expect(find.text('Feeder calibration'), findsNothing);
      expect(find.text('Roll call'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hiding private entries immediately hides history before the next database snapshot',
    (tester) async {
      events.add(
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'q',
            text: 'Private feeder decision',
            coverage: QueryCoverage(),
            private: true,
          ),
        ),
      );
      await pump(tester);
      privacy.add(true);
      await tester.pump();
      await switcher(tester);
      await tester.tap(find.text('Feeder calibration').last);
      await tester.pump();
      expect(find.text('Private feeder decision'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Private follow-up');
      privacy.add(false);
      await tester.pump();
      expect(find.text('Private feeder decision'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await switcher(tester);
      expect(find.text('Feeder calibration'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a background history error preserves the conversation and draft',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Which feeder?');
      data.addError(StateError('database temporarily unavailable'));
      await tester.pump();
      expect(find.text('Feeder calibration'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Which feeder?',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'first Send keeps narrowing choices when it creates the conversation',
    (tester) async {
      events.clear();
      when(
        () =>
            store.create('agent', scope, any(), private: any(named: 'private')),
      ).thenAnswer((call) async {
        events.add(
          event(
            'new-created',
            'new-id',
            QueryChatEventData.created(
              scope: scope,
              title: call.positionalArguments[2] as String,
            ),
          ),
        );
        data.add(snapshot());
        return 'new-id';
      });
      await pump(tester);
      await tester.tap(find.text('Home scope only'));
      await tester.tap(find.text('Recordings'));
      await tester.enterText(find.byType(TextField), 'Which feeder recording?');
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.send));
      await tester.pump();
      await tester.pump();
      expect(inferenceCalls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Which feeder recording?',
      );
      final selected = tester
          .widgetList<DesignSystemChip>(find.byType(DesignSystemChip))
          .where((chip) => chip.selected)
          .map((chip) => chip.label);
      expect(selected, ['Home scope only', 'Recordings']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final hideSource in [false, true]) {
    testWidgets(
      'rename clears sensitive text when ${hideSource ? 'its source becomes private' : 'private entries are hidden'}',
      (tester) async {
        bench.add('note', category: categoryMindfulness.id);
        events.add(
          event(
            'reply',
            'feeder',
            const QueryChatEventData.answer(
              questionId: 'q',
              text: 'Feeder decision',
              coverage: QueryCoverage(),
              dependencies: [
                QuerySourceRef(
                  id: 'note',
                  private: false,
                  categoryPrivate: false,
                ),
              ],
            ),
          ),
        );
        await pump(tester);
        if (!hideSource) {
          privacy.add(true);
          await tester.pump();
        }
        await switcher(tester);
        await tester.tap(find.byIcon(LottiIcons.more).first);
        await tester.pump();
        await tester.tap(find.text('Rename chat'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Private feeder title',
        );
        expect(find.text('Private feeder title'), findsOneWidget);
        if (hideSource) {
          bench.entries['note'] = bench.entries['note']!.copyWith(
            meta: bench.entries['note']!.meta.copyWith(private: true),
          );
          data.add(snapshot());
        } else {
          privacy.add(false);
        }
        await tester.pump();
        expect(find.text('Private feeder title'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('Save'), findsNothing);
        verifyNever(
          () => store.rename(
            any(),
            any(),
            any(),
            private: any(named: 'private'),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
