import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_chat_pane.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../projects/test_utils.dart';
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
  var failHistory = false;
  var closeCalls = 0;
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
    failHistory = false;
    closeCalls = 0;
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
          'archive-${events.length}',
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
  Future<void> pump(
    WidgetTester tester, {
    QueryScope activeScope = scope,
    QueryChatSession? session,
    bool noAgent = false,
    bool sourceDetailLoading = false,
  }) async {
    final activeKey = (agentId: 'agent', scope: activeScope);
    if (activeScope != scope) {
      for (var i = 0; i < events.length; i++) {
        if (events[i].data case final QueryChatCreated created) {
          events[i] = events[i].copyWith(
            data: created.copyWith(scope: activeScope),
          );
        }
      }
    }
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        QueryChatPane(scope: activeScope, onClose: () => closeCalls++),
        overrides: [
          if (sourceDetailLoading)
            entryControllerProvider(
              'note',
            ).overrideWithBuild((ref, notifier) async {
              ref.onDispose(() {
                notifier.controller.dispose();
                notifier.focusNode.dispose();
              });
              return null;
            }),
          queryChatTargetProvider(activeScope).overrideWith(
            (ref) async => QueryChatTarget(
              scope: activeScope,
              label: 'Inspect orbital penguin habitat',
              agent: noAgent ? null : identity,
              categoryId: categoryMindfulness.id,
              categoryLabel: categoryMindfulness.name,
            ),
          ),
          queryChatStoreProvider.overrideWithValue(store),
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          queryChatDataProvider(activeKey).overrideWith((ref) async* {
            if (failHistory) throw StateError('history unavailable');
            yield snapshot();
            yield* data.stream;
          }),
          if (session != null)
            queryChatControllerProvider(activeKey).overrideWithBuild((
              ref,
              notifier,
            ) {
              notifier.build();
              return session;
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
        find.textContaining(
          'Audio may already have been sent to your transcription provider.',
        ),
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

  testWidgets(
    'rename validates the title, preserves Cancel and saves the chosen name',
    (tester) async {
      when(
        () => store.rename(
          'agent',
          'feeder',
          any(),
          private: any(named: 'private'),
        ),
      ).thenAnswer((call) async {
        events.add(
          event(
            'rename',
            'feeder',
            QueryChatEventData.renamed(
              title: call.positionalArguments[2] as String,
            ),
          ),
        );
        data.add(snapshot());
      });
      await pump(tester);
      Future<void> openRename() async {
        await switcher(tester);
        await tester.tap(find.byIcon(LottiIcons.more).first);
        await tester.pump();
        await tester.tap(find.text('Rename chat'));
        await tester.pumpAndSettle();
      }

      await openRename();
      await tester.enterText(find.byType(TextField).last, 'Ignored rename');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Feeder calibration'), findsOneWidget);
      await openRename();
      for (final invalid in [' ', 'x' * 121]) {
        await tester.enterText(find.byType(TextField).last, invalid);
        await tester.tap(find.text('Save'));
        await tester.pump();
        verifyNever(
          () => store.rename(
            'agent',
            'feeder',
            any(),
            private: any(named: 'private'),
          ),
        );
      }
      await tester.enterText(find.byType(TextField).last, '  Chosen feeder  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(
        () => store.rename('agent', 'feeder', 'Chosen feeder'),
      ).called(1);
      expect(find.text('Chosen feeder'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'archive disables composition and restoring preserves the draft',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Feeder follow-up');
      await switcher(tester);
      await tester.tap(find.byIcon(LottiIcons.more).first);
      await tester.pump();
      await tester.tap(find.text('Archive chat'));
      await tester.pump();
      await tester.pump();
      verify(() => store.archive('agent', 'feeder', archived: true)).called(1);
      await switcher(tester);
      await tester.tap(find.text('Archived chats'));
      await tester.pump();
      await tester.tap(find.text('Feeder calibration').last);
      await tester.pump();
      expect(find.textContaining('This chat is archived.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Restore chat'));
      await tester.pump();
      await tester.pump();
      verify(() => store.archive('agent', 'feeder', archived: false)).called(1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Feeder follow-up',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isNot(false),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('New chat starts isolated and examples only populate its draft', (
    tester,
  ) async {
    when(
      () => store.create('agent', scope, 'New chat'),
    ).thenAnswer((_) async {
      events.add(
        event(
          'new-created',
          'new-id',
          const QueryChatEventData.created(scope: scope, title: 'New chat'),
        ),
      );
      data.add(snapshot());
      return 'new-id';
    });
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Old draft');
    await switcher(tester);
    await tester.tap(find.text('New chat'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    final example = find.text('In which meeting did we discuss this?');
    await tester.tap(example);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'In which meeting did we discuss this?',
    );
    expect(inferenceCalls, 0);
    await switcher(tester);
    await tester.tap(find.text('Feeder calibration').last);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Old draft',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in QueryScopeKind.values) {
    testWidgets('$kind shows its home label and closing preserves its draft', (
      tester,
    ) async {
      final activeScope = QueryScope(
        kind: kind,
        id: kind == QueryScopeKind.category ? categoryMindfulness.id : 'task',
      );
      if (kind == QueryScopeKind.project) {
        bench.entries['task'] = makeTestProject(
          id: 'task',
          categoryId: categoryMindfulness.id,
          title: 'Penguin habitat project',
        );
      } else if (kind == QueryScopeKind.task) {
        bench.entries['task'] = bench.entries['task']!.copyWith(
          meta: bench.entries['task']!.meta.copyWith(categoryId: null),
        );
      }
      await pump(tester, activeScope: activeScope);
      final label = kind == QueryScopeKind.project
          ? 'Penguin habitat project'
          : kind == QueryScopeKind.category
          ? categoryMindfulness.name
          : testTask.data.title;
      expect(find.text(label), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Saved draft');
      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pump();
      expect(closeCalls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QueryChatPane)),
      );
      expect(
        container
            .read(
              queryChatControllerProvider((
                agentId: 'agent',
                scope: activeScope,
              )),
            )
            .local('feeder')
            .draft,
        'Saved draft',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'initial history failures offer Retry and recover the conversation',
    (tester) async {
      failHistory = true;
      await pump(tester);
      expect(find.text('Feeder calibration'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      failHistory = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Feeder calibration'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('missing agent explains assignment and can return to details', (
    tester,
  ) async {
    await pump(tester, noAgent: true);
    expect(find.textContaining('usual agent assignment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byIcon(LottiIcons.back));
    await tester.pump();
    expect(closeCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'running chat exposes progress and Cancel, with other-chat status in the switcher',
    (tester) async {
      await pump(
        tester,
        session: const QueryChatSession(
          selectedId: 'feeder',
          chats: {
            'feeder': QueryChatLocal(
              status: QueryTurnStatus.running,
              checked: 7,
              expanded: true,
            ),
            'roll-call': QueryChatLocal(status: QueryTurnStatus.running),
          },
        ),
      );
      expect(find.text('Sources checked: 7'), findsOneWidget);
      expect(find.byIcon(LottiIcons.sync), findsOneWidget);
      await switcher(tester);
      expect(find.textContaining('Searching'), findsWidgets);
      await switcher(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QueryChatPane)),
      );
      expect(
        container.read(queryChatControllerProvider(key)).local('feeder').status,
        QueryTurnStatus.cancelled,
      );
      expect(
        container
            .read(queryChatControllerProvider(key))
            .local('roll-call')
            .status,
        QueryTurnStatus.running,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a persisted unanswered question can retry without editing history',
    (tester) async {
      events.add(
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(
            text: 'Which feeder did we select?',
          ),
        ),
      );
      await pump(tester);
      expect(find.text('Which feeder did we select?'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(inferenceCalls, 1);
      expect(find.textContaining('No usable inference setup'), findsOneWidget);
      expect(events.where((e) => e.data is QueryChatQuestion), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'answer evidence exposes coverage and opens its source without losing the draft',
    (tester) async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<UserActivityService>(MockUserActivityService())
            ..registerSingleton<EditorStateService>(MockEditorStateService());
        },
      );
      addTearDown(tearDownTestGetIt);
      bench.add('note', category: categoryMindfulness.id);
      final document = QuerySourceDocument.fromEntry(bench.entries['note']!)!;
      final source = QuerySourceRef(
        id: 'note',
        private: false,
        categoryPrivate: false,
        categoryId: categoryMindfulness.id,
      );
      events.addAll([
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'What was the decision?'),
        ),
        event(
          'reply',
          'feeder',
          QueryChatEventData.answer(
            questionId: 'question',
            text: 'The feeder decision is recorded [1].',
            coverage: const QueryCoverage(
              checked: 3,
              incomplete: true,
              missingTranscripts: 2,
            ),
            recalledMemoryIds: ['memory'],
            dependencies: [source],
            evidence: [
              QueryEvidence(
                source: source,
                kind: document.kind,
                label: 'Feeder meeting',
                sourceDate: document.entry.meta.dateFrom,
                textVersion: document.version,
                fingerprint: document.fingerprint,
                sourceText: document.text,
                start: 0,
                end: document.text.length,
                summary: 'Feeder discussion',
              ),
            ],
          ),
        ),
      ]);
      await pump(tester, sourceDetailLoading: true);
      await tester.enterText(find.byType(TextField), 'Follow-up draft');
      expect(
        find.textContaining('The feeder decision is recorded (1).'),
        findsOneWidget,
      );
      expect(
        find.text('Uses relevant conclusions from earlier chats.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('What was searched'));
      await tester.tap(find.text('What was searched'));
      await tester.pumpAndSettle();
      expect(find.text('Sources checked: 3'), findsOneWidget);
      expect(
        find.textContaining('2 recordings have no searchable text'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Show exact text'));
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      await tester.ensureVisible(find.text('Open entry'));
      await tester.tap(find.text('Open entry'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
        'note',
      );
      bench.entries['note'] = bench.entries['note']!.copyWith(
        meta: bench.entries['note']!.meta.copyWith(private: true),
      );
      data.add(snapshot());
      await tester.pump();
      expect(find.byType(EntryDetailsPage), findsNothing);
      expect(find.text('Feeder meeting'), findsNothing);
      bench.entries['note'] = document.entry;
      data.add(snapshot());
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.back).first);
      await tester.pump();
      expect(find.byType(EntryDetailsPage), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Follow-up draft',
      );
      expect(closeCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
