import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_transcription_provider.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_audio_controls.dart';
import 'package:lotti/features/agents/ui/query/query_chat_pane.dart';
import 'package:lotti/features/agents/ui/query/query_evidence_card.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
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
  setUp(() async {
    await setUpTestGetIt();
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
    await tearDownTestGetIt();
  });
  Future<void> pump(
    WidgetTester tester, {
    QueryScope activeScope = scope,
    MediaQueryData? mediaQueryData,
    QueryChatSession? session,
    Stream<bool>? featureFlag,
    bool noAgent = false,
    bool companion = false,
    bool sourceDetailLoading = false,
    String sourceDetailId = 'note',
    ChatRecorderController? activeRecorder,
    ChatTranscriptionTargetResolver? transcriptionResolver,
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
        QueryChatPane(
          scope: activeScope,
          onClose: () => closeCalls++,
          companion: companion,
        ),
        mediaQueryData: mediaQueryData,
        overrides: [
          if (sourceDetailLoading)
            entryControllerProvider(
              sourceDetailId,
            ).overrideWithBuild((ref, notifier) async {
              ref.onDispose(() {
                notifier.controller.dispose();
                notifier.focusNode.dispose();
              });
              return null;
            }),
          if (featureFlag == null)
            queryChatEnabledProvider.overrideWithValue(true)
          else
            configFlagProvider(
              'enable_query_chat',
            ).overrideWith((ref) => featureFlag),
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
          queryTranscriptionTargetResolverProvider(
            activeScope,
          ).overrideWithValue(
            transcriptionResolver ??
                () async => throw StateError('Not submitted'),
          ),
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
          chatRecorderControllerProvider.overrideWith(
            () => activeRecorder ?? recorder,
          ),
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

  QueryEvidence addCitationAnswer(String suffix, {String? answerText}) {
    final sourceId = 'note-$suffix';
    bench.add(sourceId, category: categoryMindfulness.id);
    final document = QuerySourceDocument.fromEntry(bench.entries[sourceId]!)!;
    final source = QuerySourceRef(
      id: sourceId,
      categoryId: categoryMindfulness.id,
      private: false,
      categoryPrivate: false,
    );
    final evidence = QueryEvidence(
      source: source,
      kind: document.kind,
      label: 'Habitat meeting $suffix',
      summary: 'Recorded habitat decision $suffix',
      sourceDate: document.entry.meta.dateFrom,
      textVersion: document.version,
      fingerprint: document.fingerprint,
      sourceText: document.text,
      start: 0,
      end: document.text.length,
    );
    events.addAll([
      event(
        'question-$suffix',
        'feeder',
        QueryChatEventData.question(text: 'Decision $suffix?'),
      ),
      event(
        'reply-$suffix',
        'feeder',
        QueryChatEventData.answer(
          questionId: 'question-$suffix',
          text: answerText ?? 'Decision $suffix is recorded [1].',
          coverage: const QueryCoverage(),
          dependencies: [source],
          evidence: [evidence],
        ),
      ),
    ]);
    return evidence;
  }

  Finder citationIn(String suffix, {String number = '1'}) => find.descendant(
    of: find.descendant(
      of: find.byKey(ValueKey('goal-chat-message-reply-$suffix')),
      matching: find.byType(AgentMarkdownView),
    ),
    matching: find.text(number, findRichText: true),
  );

  testWidgets('disabling the feature hides open chat and cancels dictation', (
    tester,
  ) async {
    final flags = StreamController<bool>.broadcast();
    addTearDown(flags.close);
    var cancelled = false;
    await pump(
      tester,
      featureFlag: flags.stream,
      activeRecorder: ProcessingTestController(
        partialTranscript: null,
        onCancelCalled: () => cancelled = true,
      ),
    );
    expect(find.text('Feeder calibration'), findsNothing);
    verifyNever(() => store.markRead(any(), any(), any()));
    flags.add(true);
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump();
    }
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(QueryChatPane)),
      ).read(queryChatEnabledProvider),
      isTrue,
    );
    expect(find.text('Feeder calibration'), findsOneWidget);
    expect(cancelled, isFalse);
    flags.add(false);
    await tester.pump();
    expect(find.text('Feeder calibration'), findsNothing);
    expect(cancelled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final projectOwner in [false, true]) {
    testWidgets(
      'summary answers disclose their basis and open attributed owners (project=$projectOwner)',
      (
        tester,
      ) async {
        getIt
          ..registerSingleton<UserActivityService>(MockUserActivityService())
          ..registerSingleton<EditorStateService>(MockEditorStateService());
        final task = bench.entries['task']! as Task;
        bench.entries['task'] = task.copyWith(
          data: task.data.copyWith(title: 'Feeder approval'),
        );
        final ownerId = projectOwner ? 'project' : 'task';
        if (projectOwner) {
          bench.entries['project'] = makeTestProject(
            id: 'project',
            categoryId: categoryMindfulness.id,
            title: 'Feeder project',
          );
        }
        final ownerTitle = projectOwner ? 'Feeder project' : 'Feeder approval';
        events.addAll([
          event(
            'question',
            'feeder',
            const QueryChatEventData.question(text: 'What was approved?'),
          ),
          event(
            'reply',
            'feeder',
            QueryChatEventData.answer(
              questionId: 'question',
              text: 'The summary records approval.',
              coverage: const QueryCoverage(incomplete: true),
              summaryBased: true,
              summaryOwnerIds: [ownerId, 'unknown'],
              dependencies: [
                QuerySourceRef(
                  id: ownerId,
                  private: false,
                  categoryPrivate: false,
                  categoryId: categoryMindfulness.id,
                ),
              ],
            ),
          ),
        ]);
        await pump(tester, sourceDetailLoading: true, sourceDetailId: ownerId);
        expect(find.textContaining('Sources checked: 0'), findsNothing);
        expect(
          find.text(
            'Some information is missing from the available summaries.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AgentMarkdownView>(find.byType(AgentMarkdownView).last)
              .text,
          contains('Based on summaries'),
        );
        await tester.tap(find.text('About this answer'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This answer uses task or project summaries. Original entries were not inspected.',
          ),
          findsOneWidget,
        );
        expect(find.text('unknown'), findsNothing);
        await tester.ensureVisible(find.text(ownerTitle).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(ownerTitle).last);
        await tester.pump();
        expect(
          tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
          ownerId,
        );
        await tester.tap(find.byIcon(LottiIcons.back));
        await tester.pump();
        expect(find.text('About this answer'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('original-entry filters explain their actual task-only reach', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    expect(
      find.text('Checks this task and its directly linked entries only.'),
      findsOneWidget,
    );
    final chips = tester.widgetList<DesignSystemChip>(
      find.byType(DesignSystemChip),
    );
    final home = chips.singleWhere((chip) => chip.label == 'Home scope only');
    expect(home.selected, isTrue);
    expect(home.onPressed, isNull);
    await tester.tap(find.text('Summaries'));
    await tester.pump();
    expect(
      find.text('Checks this task and its directly linked entries only.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in [QueryScopeKind.project, QueryScopeKind.category]) {
    testWidgets('$kind offers no unsupported original-entry filters', (
      tester,
    ) async {
      bench.entries[categoryMindfulness.id] = makeTestProject(
        id: categoryMindfulness.id,
        categoryId: categoryMindfulness.id,
        title: 'Penguin logistics',
      );
      await pump(
        tester,
        activeScope: QueryScope(kind: kind, id: categoryMindfulness.id),
      );
      expect(find.text('Notes'), findsNothing);
      expect(find.text('Recordings'), findsNothing);
      expect(find.text('Summaries'), findsNothing);
      expect(find.text('Feeder calibration'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'compact companion shows its task title and discloses scope controls at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bench.entries['task'] = (bench.entries['task']! as Task).copyWith(
        data: testTask.data.copyWith(title: 'Inspect orbital penguin habitat'),
      );
      await pump(
        tester,
        companion: true,
        mediaQueryData: const MediaQueryData(
          size: Size(320, 844),
          textScaler: TextScaler.linear(1.5),
        ),
      );
      final title = find.text('Inspect orbital penguin habitat');
      expect(
        tester.renderObject<RenderParagraph>(title).maxLines,
        2,
      );
      expect(find.text('Notes'), findsNothing);
      await tester.tap(find.byIcon(LottiIcons.filter));
      await tester.pump();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Recordings'), findsOneWidget);
      await tester.tap(find.byIcon(LottiIcons.filter));
      await tester.pump();
      expect(find.text('Notes'), findsNothing);
      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pump();
      expect(closeCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline citations expand only their own answer evidence',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1200, 2200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = addCitationAnswer('a');
      final second = addCitationAnswer('b');
      await pump(tester);
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(citationIn('b'));
      await tester.pump();
      await tester.pump();
      expect(find.text(second.quote, findRichText: true), findsOneWidget);
      expect(find.text(first.quote, findRichText: true), findsNothing);
      await tester.ensureVisible(citationIn('a'));
      await tester.tap(citationIn('a'));
      await tester.pump();
      await tester.pump();
      expect(find.text(first.quote, findRichText: true), findsOneWidget);
      expect(find.text(second.quote, findRichText: true), findsOneWidget);
      expect(find.byType(EntryDetailsPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final separator in [' ', '']) {
    testWidgets(
      'adjacent citations each open their own evidence (spaced=${separator.isNotEmpty})',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 2200)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = addCitationAnswer(
          'adjacent',
          answerText: 'The habitat decision has two sources [1]$separator[2].',
        );
        final second = addCitationAnswer('second');
        events.removeWhere(
          (event) =>
              event.id == 'question-second' || event.id == 'reply-second',
        );
        final index = events.indexWhere(
          (event) => event.id == 'reply-adjacent',
        );
        final answer = events[index].data as QueryChatAnswer;
        events[index] = events[index].copyWith(
          data: answer.copyWith(
            evidence: [first, second],
            dependencies: [first.source, second.source],
          ),
        );
        await pump(tester);
        expect(find.byType(SelectableText), findsNothing);
        await tester.tap(citationIn('adjacent'));
        await tester.pump();
        await tester.pump();
        expect(find.text(first.quote, findRichText: true), findsOneWidget);
        expect(find.text(second.quote, findRichText: true), findsNothing);
        final secondLink = citationIn('adjacent', number: '2');
        await tester.ensureVisible(secondLink);
        await tester.tap(secondLink);
        await tester.pump();
        await tester.pump();
        expect(find.text(first.quote, findRichText: true), findsOneWidget);
        expect(find.text(second.quote, findRichText: true), findsOneWidget);
        expect(find.byType(EntryDetailsPage), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('defined numeric reference remains an external link', (
    tester,
  ) async {
    const answer =
        'Reference [1][2] stays external.\n\n'
        '[2]: https://example.com/habitat';
    addCitationAnswer('numeric-reference', answerText: answer);
    await pump(tester);
    expect(
      tester.widget<AgentMarkdownView>(find.byType(AgentMarkdownView)).text,
      answer,
    );
    expect(find.byType(SelectableText), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'citation routing preserves literal code and reference links',
    (tester) async {
      const answer =
          'Inline `[1]` stays literal.\n\n'
          '```text\n[1]\n```\n\n'
          'Reference [1][source] stays external.\n\n'
          '[source]: https://example.com/habitat\n\n'
          'Bare [1].';
      final evidence = addCitationAnswer('syntax', answerText: answer);
      await pump(tester);
      final markdown = tester.widget<AgentMarkdownView>(
        find.byType(AgentMarkdownView),
      );
      expect(
        markdown.text,
        'Inline `[1]` stays literal.\n\n'
        '```text\n[1]\n```\n\n'
        'Reference [1][source] stays external.\n\n'
        '[source]: https://example.com/habitat\n\n'
        'Bare [1](#query-evidence-1).',
      );
      markdown.onLinkTap!('#query-evidence-1', '');
      await tester.pump();
      await tester.pump();
      expect(find.text(evidence.quote, findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'inline citation reloads source privacy before revealing stored text',
    (tester) async {
      final evidence = addCitationAnswer('private');
      await pump(tester);
      expect(
        find.textContaining(evidence.label, findRichText: true),
        findsOneWidget,
      );
      // Keep the rendered snapshot unchanged; only the fresh journal lookup
      // observes that the source was made private after the link appeared.
      final source = bench.entries[evidence.source.id]!;
      bench.entries[evidence.source.id] = source.copyWith(
        meta: source.meta.copyWith(private: true),
      );
      await tester.tap(citationIn('private'));
      await tester.pump();
      await tester.pump();
      expect(find.text(evidence.quote, findRichText: true), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(EntryDetailsPage), findsNothing);
      // A denied attempt must not poison the legitimate restored action.
      bench.entries[evidence.source.id] = source;
      await tester.tap(citationIn('private'));
      await tester.pump();
      await tester.pump();
      expect(find.text(evidence.quote, findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final forgotten in [false, true]) {
    testWidgets(
      'unavailable recalled memory leaves no existence hint (forgotten=$forgotten)',
      (tester) async {
        events.addAll([
          event(
            'memory',
            'roll-call',
            QueryChatEventData.memory(
              questionId: 'origin',
              text: 'A private feeder conclusion',
              private: !forgotten,
            ),
          ),
          if (forgotten)
            event(
              'forgotten',
              'roll-call',
              const QueryChatEventData.deleted(forget: true),
            ),
          event(
            'question',
            'feeder',
            const QueryChatEventData.question(text: 'Public feeder question'),
          ),
          event(
            'reply',
            'feeder',
            const QueryChatEventData.answer(
              questionId: 'question',
              text: 'Public feeder answer',
              coverage: QueryCoverage(),
              recalledMemoryIds: ['memory'],
            ),
          ),
        ]);
        await pump(tester);
        expect(find.text('Public feeder answer'), findsOneWidget);
        expect(find.text('This answer used saved conclusions.'), findsNothing);
        expect(find.text('A private feeder conclusion'), findsNothing);
        expect(
          find.byKey(const PageStorageKey('recall:question')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'chat picker announces selection and archive disclosure state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        events.add(
          event(
            'archived',
            'roll-call',
            const QueryChatEventData.archived(archived: true),
          ),
        );
        await pump(tester);
        final picker = find.bySemanticsLabel('Chats: Feeder calibration');
        expect(
          tester.getSemantics(picker).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        await tester.tap(picker);
        await tester.pump();
        expect(
          tester.getSemantics(picker).flagsCollection.isExpanded,
          Tristate.isTrue,
        );
        final archive = find.bySemanticsLabel('Archived chats · 1');
        expect(
          tester.getSemantics(archive).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        expect(find.text('Roll call'), findsNothing);
        await tester.tap(archive);
        await tester.pump();
        expect(
          tester.getSemantics(archive).flagsCollection.isExpanded,
          Tristate.isTrue,
        );
        await tester.tap(find.text('Roll call'));
        await tester.pump();
        final selected = find.bySemanticsLabel('Chats: Roll call');
        expect(
          tester.getSemantics(selected).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        expect(
          find.bySemanticsLabel('Chats: Feeder calibration'),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'question cards keep a readable measure and prepare an editable draft',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1200, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      events.clear();
      await pump(tester);
      final suggestion = find.text('Was that a decision or a suggestion?');
      final card = find
          .ancestor(of: suggestion, matching: find.byType(InkWell))
          .first;
      final rect = tester.getRect(card);
      expect(rect.width, lessThanOrEqualTo(520));
      expect(rect.center.dx, closeTo(600, 1));
      expect(
        rect.top,
        greaterThan(
          tester
              .getBottomLeft(find.text('Ask Habitat Watcher about this task'))
              .dy,
        ),
      );
      await tester.tap(suggestion);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Was that a decision or a suggestion?',
      );
      expect(inferenceCalls, 0);
      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pump();
      expect(closeCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<void> switcher(WidgetTester tester) async {
    await tester.tap(find.byIcon(LottiIcons.chevronDown).first);
    await tester.pump();
  }

  for (final retracted in [false, true]) {
    testWidgets('query synthesis provisional retracted=$retracted is honest', (
      tester,
    ) async {
      events.add(
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'What was recorded?'),
        ),
      );
      if (retracted) {
        events.add(
          event(
            'failure',
            'feeder',
            const QueryChatEventData.failed(questionId: 'question'),
          ),
        );
      }
      await pump(
        tester,
        session: QueryChatSession(
          selectedId: 'feeder',
          chats: {
            'feeder': QueryChatLocal(
              status: retracted
                  ? QueryTurnStatus.failed
                  : QueryTurnStatus.running,
              answering: true,
              requestQuestionId: 'question',
              draftRetracted: retracted,
              provisional: retracted
                  ? null
                  : const QueryChatAnswer(
                      questionId: 'question',
                      text: 'Recorded 37 penguins [1]',
                      coverage: QueryCoverage(checked: 1),
                    ),
            ),
          },
        ),
      );
      if (retracted) {
        expect(
          find.text('The draft answer could not be verified. Try again.'),
          findsOneWidget,
        );
        expect(find.text('Recorded 37 penguins [1]'), findsNothing);
        expect(find.text('Try Again'), findsOneWidget);
      } else {
        expect(find.text('Draft · not yet verified'), findsOneWidget);
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const ValueKey('query-provisional-question')),
              )
              .data,
          'Recorded 37 penguins [1]',
        );
        expect(find.byType(AgentMarkdownView), findsNothing);
      }
    });
  }

  for (final answering in [false, true]) {
    testWidgets(
      'query activity reports the actual answering=$answering phase',
      (tester) async {
        await pump(
          tester,
          session: QueryChatSession(
            selectedId: 'feeder',
            chats: {
              'feeder': QueryChatLocal(
                status: QueryTurnStatus.running,
                answering: answering,
              ),
            },
          ),
        );
        final label = answering
            ? 'Preparing an answer…'
            : 'Checking available information…';
        expect(
          tester
              .widget<DesignSystemTextInput>(find.byType(DesignSystemTextInput))
              .helperText,
          isNull,
        );
        expect(find.text('Habitat Watcher is replying…'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'Next feeder question');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        expect(inferenceCalls, 0);
        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(QueryChatPane)),
          ).read(queryChatControllerProvider(key)).local('feeder').draft,
          'Next feeder question',
        );
        await switcher(tester);
        expect(find.text(label), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final kind in QueryScopeKind.values) {
    testWidgets(
      'empty ${kind.name} chat explains scope and drafts an example',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final activeScope = QueryScope(
          kind: kind,
          id: switch (kind) {
            QueryScopeKind.task => 'task',
            QueryScopeKind.project => 'project',
            QueryScopeKind.category => categoryMindfulness.id,
          },
        );
        bench.entries['project'] = makeTestProject(
          id: 'project',
          categoryId: categoryMindfulness.id,
        );
        await pump(tester, activeScope: activeScope);
        expect(
          find.text('Ask Habitat Watcher about this ${kind.name}'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Ask about decisions and earlier work. Answers distinguish summaries from exact passages.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('What did we agree on?'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'What did we agree on?',
        );
        expect(inferenceCalls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'failure before saving keeps the draft without claiming it is saved',
    (tester) async {
      await pump(
        tester,
        session: const QueryChatSession(
          selectedId: 'feeder',
          chats: {
            'feeder': QueryChatLocal(
              status: QueryTurnStatus.failed,
              draft: 'Which feeder?',
            ),
          },
        ),
      );
      expect(
        find.text('The search could not finish. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Your question is saved'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Which feeder?',
      );
      expect(inferenceCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('narrow large-text chat keeps the composer above the keyboard', (
    tester,
  ) async {
    const size = Size(320, 760);
    const keyboard = 240.0;
    setTestSurfaceSize(tester, size);
    await pump(
      tester,
      mediaQueryData: const MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(1.5),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
    );
    final input = find.byType(TextField);
    expect(MediaQuery.textScalerOf(tester.element(input)).scale(10), 15);
    await tester.enterText(
      input,
      'A longer feeder question prepared with a large system font',
    );
    await tester.pump();
    expect(
      tester.getRect(input).bottom,
      lessThanOrEqualTo(size.height - keyboard),
    );
    expect(tester.getRect(input).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(input).right, lessThanOrEqualTo(size.width));
    await switcher(tester);
    await tester.tap(find.byIcon(LottiIcons.more).first);
    await tester.pump();
    expect(find.text('Rename chat'), findsOneWidget);
    expect(find.text('Archive chat'), findsOneWidget);
    expect(find.text('Delete chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(QueryChatPane)),
      ).read(queryChatControllerProvider(key)).local('feeder').draft,
      'A longer feeder question prepared with a large system font',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching conversations preserves independent editable drafts', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Which feeder?');
    await switcher(tester);
    final rows = tester.widgetList<DesignSystemListItem>(
      find.byType(DesignSystemListItem),
    );
    expect(
      rows.singleWhere((row) => row.title == 'Feeder calibration').activated,
      isTrue,
    );
    expect(
      rows.singleWhere((row) => row.title == 'Roll call').activated,
      isFalse,
    );
    final selectedRow = find.ancestor(
      of: find.text('Feeder calibration').last,
      matching: find.byType(DesignSystemListItem),
    );
    expect(
      find.descendant(
        of: selectedRow,
        matching: find.byIcon(LottiIcons.archive),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: selectedRow,
        matching: find.byIcon(LottiIcons.delete),
      ),
      findsNothing,
    );
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
    'dictation passes the category resolver without resolving on record',
    (
      tester,
    ) async {
      var resolutions = 0;
      Future<Never> resolver() async {
        resolutions++;
        throw StateError('Resolution belongs to Stop');
      }

      final capturingRecorder = IdleCallbackController();
      await pump(
        tester,
        activeRecorder: capturingRecorder,
        transcriptionResolver: resolver,
      );
      await tester.tap(find.byIcon(LottiIcons.mic));
      await tester.pump();
      expect(capturingRecorder.lastTranscriptionTargetResolver, same(resolver));
      expect(resolutions, 0);
      expect(inferenceCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'transcription discloses audio delivery without sending a question',
    (tester) async {
      await pump(
        tester,
        activeRecorder: ProcessingTestController(partialTranscript: null),
      );
      expect(
        find.text(
          'Transcribing your recording. Audio may already be with your provider.',
        ),
        findsOneWidget,
      );
      expect(inferenceCalls, 0);
      verifyNever(
        () => store.ask(any(), any(), any(), private: any(named: 'private')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed chat creation shows an error and preserves the draft', (
    tester,
  ) async {
    when(
      () => store.create('agent', scope, 'New chat'),
    ).thenThrow(StateError('database unavailable'));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Unsent feeder question');
    await switcher(tester);
    await tester.tap(find.text('New chat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Error'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Unsent feeder question',
    );
    expect(inferenceCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'category chat recall and rename disappear when its category becomes private',
    (tester) async {
      final categoryScope = QueryScope(
        kind: QueryScopeKind.category,
        id: categoryMindfulness.id,
      );
      events.add(
        event(
          'recalled',
          'older-chat',
          const QueryChatEventData.memory(
            questionId: 'older-question',
            text: 'Feeder selected.',
          ),
        ),
      );
      await pump(tester, activeScope: categoryScope);
      expect(
        find.text('Conclusions available from earlier chats: 1'),
        findsOneWidget,
      );
      await switcher(tester);
      await tester.tap(find.byIcon(LottiIcons.more).first);
      await tester.pump();
      await tester.tap(find.text('Rename chat'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Sensitive category title',
      );
      bench.categories[0] = bench.categories[0].copyWith(private: true);
      data.add(snapshot());
      await tester.pump();
      expect(find.text('Sensitive category title'), findsNothing);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This scope is no longer available with your current visibility settings.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Conclusions available from earlier chats: 1'),
        findsNothing,
      );
      verifyNever(
        () => store.rename(any(), any(), any(), private: any(named: 'private')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
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
        await tester.tap(
          find.text(
            forget
                ? 'Delete and forget conclusions'
                : 'Delete and keep conclusions',
          ),
        );
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
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
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

  testWidgets(
    'category coverage names the category without a wider home layer',
    (tester) async {
      events.addAll([
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'Category decision?'),
        ),
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'question',
            text: 'Category answer.',
            coverage: QueryCoverage(
              checked: 7,
              homeChecked: 7,
              categoryChecked: 0,
            ),
          ),
        ),
      ]);
      await pump(
        tester,
        activeScope: QueryScope(
          kind: QueryScopeKind.category,
          id: categoryMindfulness.id,
        ),
      );
      await tester.tap(find.text('What was searched'));
      await tester.pumpAndSettle();
      expect(find.text('This category · Sources checked: 7'), findsOneWidget);
      expect(find.text('Home scope · Sources checked: 7'), findsNothing);
      expect(
        find.text('Other entries in this category · Sources checked: 0'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
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

  for (final restoreFromMenu in [false, true]) {
    testWidgets(
      'archive disables composition and restoring preserves the draft (restoreFromMenu=$restoreFromMenu)',
      (tester) async {
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'Feeder follow-up');
        await switcher(tester);
        await tester.tap(find.byIcon(LottiIcons.more).first);
        await tester.pump();
        await tester.tap(find.text('Archive chat'));
        await tester.pump();
        await tester.pump();
        verify(
          () => store.archive('agent', 'feeder', archived: true),
        ).called(1);
        await switcher(tester);
        await tester.tap(find.text('Archived chats · 1'));
        await tester.pump();
        await tester.tap(find.text('Feeder calibration').last);
        await tester.pump();
        expect(find.textContaining('This chat is archived.'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        if (restoreFromMenu) {
          await switcher(tester);
          await tester.tap(find.byIcon(LottiIcons.more).first);
          await tester.pump();
          await tester.tap(find.text('Restore chat'));
        } else {
          await tester.tap(find.text('Restore chat'));
        }
        await tester.pump();
        await tester.pump();
        verify(
          () => store.archive('agent', 'feeder', archived: false),
        ).called(1);
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
  }

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
      final scopeLabel = switch (kind) {
        QueryScopeKind.task => 'Task',
        QueryScopeKind.project => 'Project',
        QueryScopeKind.category => 'Category',
      };
      expect(find.text(label), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip && widget.message == '$scopeLabel · $label',
        ),
        findsOneWidget,
      );
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
      expect(find.text('Try Again'), findsOneWidget);
      failHistory = false;
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Feeder calibration'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
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

  testWidgets('phone progress and Cancel remain above the composer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 422));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    events.addAll([
      event(
        'earlier-question',
        'feeder',
        const QueryChatEventData.question(text: 'Earlier feeder decision?'),
      ),
      event(
        'earlier-answer',
        'feeder',
        QueryChatEventData.answer(
          questionId: 'earlier-question',
          text: List.filled(80, 'The feeder was approved.').join(' '),
          coverage: const QueryCoverage(),
        ),
      ),
    ]);
    await pump(
      tester,
      companion: true,
      session: const QueryChatSession(
        selectedId: 'feeder',
        chats: {
          'feeder': QueryChatLocal(status: QueryTurnStatus.running, checked: 7),
        },
      ),
    );
    final composer = tester.getRect(find.byType(TextField));
    final progress = tester.getRect(find.text('Sources checked: 7'));
    final cancel = tester.getRect(find.text('Cancel'));
    expect(progress.bottom, lessThan(composer.top));
    expect(cancel.bottom, lessThan(composer.top));
    expect(progress.top, greaterThan(0));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Sources checked: 7'), findsNothing);
    expect(tester.takeException(), isNull);
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
      expect(
        find.bySemanticsLabel('Checking available information…'),
        findsWidgets,
      );
      await switcher(tester);
      expect(
        find.textContaining('Checking available information'),
        findsWidgets,
      );
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
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(inferenceCalls, 1);
      expect(find.textContaining('No usable inference setup'), findsOneWidget);
      expect(events.where((e) => e.data is QueryChatQuestion), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final companion in [false, true]) {
    testWidgets(
      'answer evidence exposes coverage and opens its source without losing the draft (companion=$companion)',
      (tester) async {
        getIt
          ..registerSingleton<UserActivityService>(MockUserActivityService())
          ..registerSingleton<EditorStateService>(MockEditorStateService());
        bench.add('note', category: categoryMindfulness.id);
        bench.entries['note'] = testAudioEntry.copyWith(
          meta: bench.entries['note']!.meta,
          entryText: bench.entries['note']!.entryText,
        );
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
        await pump(tester, sourceDetailLoading: true, companion: companion);
        expect(find.text('Prepare audio excerpt'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Follow-up draft');
        expect(
          find.textContaining(
            'The feeder decision is recorded',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.text('This answer used saved conclusions.'),
          findsNothing,
        );
        const explanation =
            'Coverage is incomplete. Missing evidence does not mean the discussion never happened.';
        expect(find.text(explanation), findsNothing);
        final shortWarning = find.text('Some sources could not be checked.');
        expect(shortWarning, findsOneWidget);
        final tokens = tester.element(shortWarning).designTokens;
        expect(
          tester.widget<Text>(shortWarning).style,
          tokens.typography.styles.others.caption,
        );
        await tester.ensureVisible(find.text('What was searched'));
        await tester.pump();
        await tester.tap(find.text('What was searched'));
        await tester.pumpAndSettle();
        expect(find.text('Sources checked: 3'), findsOneWidget);
        expect(find.text(explanation), findsOneWidget);
        expect(
          find.textContaining('2 recordings had no searchable text'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Show exact text'));
        await tester.pump();
        await tester.tap(find.text('Show exact text'));
        await tester.pump();
        await tester.ensureVisible(find.text('Open entry'));
        await tester.pump();
        await tester.tap(find.text('Open entry'));
        await tester.pump();
        await tester.pump();
        expect(
          tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
          'note',
        );
        expect(find.byIcon(LottiIcons.back), findsOneWidget);
        expect(
          find.byIcon(LottiIcons.close),
          companion ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byIcon(LottiIcons.back));
        await tester.pump();
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<QueryEvidenceCardState>(),
          isNotNull,
        );
        await tester.ensureVisible(find.text('Open entry'));
        await tester.pump();
        await tester.tap(find.text('Open entry'));
        await tester.pump();
        bench.entries['note'] = bench.entries['note']!.copyWith(
          meta: bench.entries['note']!.meta.copyWith(private: true),
        );
        data.add(snapshot());
        await tester.pump();
        await tester.pump();
        expect(find.byType(EntryDetailsPage), findsNothing);
        expect(find.text('Feeder meeting'), findsNothing);
        bench.entries['note'] = document.entry;
        data.add(snapshot());
        await tester.pump();
        await tester.pump();
        // Losing source access already returned to chat without a placeholder.
        expect(find.byType(EntryDetailsPage), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Follow-up draft',
        );
        expect(closeCalls, 0);
        final navigation = RecordingMockNavService();
        getIt.registerSingleton<NavService>(navigation);
        final audioControls = tester.widget<QueryEvidenceAudioControls>(
          find.byType(QueryEvidenceAudioControls),
        );
        audioControls.onOpenSettings();
        expect(navigation.navigationHistory, ['/settings/ai']);
        // The media widget tests exercise the visible recovery buttons. Here the
        // pane's callbacks must recheck access even before its snapshot updates.
        bench.entries['note'] = document.entry.copyWith(
          meta: document.entry.meta.copyWith(private: true),
        );
        audioControls.onOpenEntry();
        await tester.pump();
        await tester.pump();
        expect(find.byType(EntryDetailsPage), findsNothing);
        bench.entries['note'] = document.entry;
        audioControls.onOpenEntry();
        await tester.pump();
        await tester.pump();
        expect(
          tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
          'note',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'an older failed question retains its own retry after a later answer',
    (tester) async {
      events.addAll([
        event(
          'question-1',
          'feeder',
          const QueryChatEventData.question(text: 'Which feeder?'),
        ),
        event(
          'question-2',
          'feeder',
          const QueryChatEventData.question(text: 'When was roll call?'),
        ),
        event(
          'failed',
          'feeder',
          const QueryChatEventData.failed(questionId: 'question-1'),
        ),
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'question-2',
            text: 'Roll call was at dawn.',
            coverage: QueryCoverage(),
          ),
        ),
      ]);
      await pump(tester);
      final first = find.byKey(
        const ValueKey('goal-chat-attachment-question-1'),
      );
      final retry = find.descendant(
        of: first,
        matching: find.text('Try Again'),
      );
      expect(
        find.descendant(
          of: first,
          matching: find.text('The search could not finish. Try again.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('goal-chat-attachment-question-2')),
          matching: find.text('Try Again'),
        ),
        findsNothing,
      );
      await tester.tap(retry);
      await tester.pump();
      expect(inferenceCalls, 1);
      expect(
        events.where((event) => event.data is QueryChatQuestion),
        hasLength(2),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final saved in [false, true]) {
    testWidgets(
      'missing setup opens AI settings beside its question (saved=$saved)',
      (tester) async {
        final navigation = RecordingMockNavService();
        getIt.registerSingleton<NavService>(navigation);
        if (saved) {
          events.add(
            event(
              'question',
              'feeder',
              const QueryChatEventData.question(text: 'Saved feeder question'),
            ),
          );
        }
        await pump(
          tester,
          session: QueryChatSession(
            selectedId: 'feeder',
            chats: {
              'feeder': QueryChatLocal(
                status: QueryTurnStatus.unavailable,
                requestQuestionId: saved ? 'question' : null,
                draft: 'Feeder follow-up',
              ),
            },
          ),
        );
        expect(find.text('AI Settings'), findsOneWidget);
        expect(find.text('Try Again'), saved ? findsOneWidget : findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('goal-chat-attachment-question')),
            matching: find.text('AI Settings'),
          ),
          saved ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('AI Settings'));
        expect(navigation.navigationHistory, ['/settings/ai']);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Feeder follow-up',
        );
        if (saved) {
          await tester.tap(find.text('Try Again'));
          await tester.pump();
          await tester.pump();
          expect(inferenceCalls, 1);
          expect(
            events.where((event) => event.data is QueryChatQuestion),
            hasLength(1),
          );
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'recalled conclusions can be inspected and opened in their original chat',
    (tester) async {
      events.addAll([
        event(
          'memory',
          'roll-call',
          const QueryChatEventData.memory(
            questionId: 'origin',
            text: 'The spare feeder is a suggestion.',
          ),
        ),
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'Was it decided?'),
        ),
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'question',
            text: 'It was a suggestion.',
            coverage: QueryCoverage(),
            recalledMemoryIds: ['memory'],
          ),
        ),
      ]);
      await pump(tester);
      expect(find.text('The spare feeder is a suggestion.'), findsNothing);
      await tester.tap(
        find.text('This answer used saved conclusions.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('The spare feeder is a suggestion.'), findsOneWidget);
      expect(find.text('Conclusion saved Jul 17, 2026 10:00'), findsOneWidget);
      await tester.tap(find.text('Roll call'));
      await tester.pump();
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(QueryChatPane)),
        ).read(queryChatControllerProvider(key)).selectedId,
        'roll-call',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'retained conclusion shows its saved date without naming the deleted origin',
    (tester) async {
      events.addAll([
        event(
          'memory',
          'roll-call',
          const QueryChatEventData.memory(
            questionId: 'origin',
            text: 'The spare feeder remained a suggestion.',
          ),
        ),
        event(
          'deleted-origin',
          'roll-call',
          const QueryChatEventData.deleted(forget: false),
        ),
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'Was the spare agreed?'),
        ),
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'question',
            text: 'The spare was suggested.',
            coverage: QueryCoverage(),
            recalledMemoryIds: ['memory'],
          ),
        ),
      ]);
      await pump(tester);
      await tester.tap(find.text('This answer used saved conclusions.'));
      await tester.pumpAndSettle();
      expect(
        find.text('The spare feeder remained a suggestion.'),
        findsOneWidget,
      );
      expect(find.text('Conclusion saved Jul 17, 2026 10:00'), findsOneWidget);
      expect(find.text('Roll call'), findsNothing);
      expect(find.textContaining('origin unavailable'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed unsaved follow-up remains visible after an answered question',
    (tester) async {
      events.addAll([
        event(
          'question',
          'feeder',
          const QueryChatEventData.question(text: 'First question'),
        ),
        event(
          'reply',
          'feeder',
          const QueryChatEventData.answer(
            questionId: 'question',
            text: 'First answer',
            coverage: QueryCoverage(),
          ),
        ),
      ]);
      await pump(
        tester,
        session: const QueryChatSession(
          selectedId: 'feeder',
          chats: {
            'feeder': QueryChatLocal(
              status: QueryTurnStatus.failed,
              draft: 'Second question',
            ),
          },
        ),
      );
      expect(
        find.text('The search could not finish. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Second question',
      );
      expect(find.text('Try Again'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final hideSource in [false, true]) {
    testWidgets(
      'unreadable recording recovery rechecks live privacy (hidden=$hideSource)',
      (tester) async {
        getIt
          ..registerSingleton<UserActivityService>(MockUserActivityService())
          ..registerSingleton<EditorStateService>(MockEditorStateService());
        bench.entries['unreadable'] = testAudioEntry.copyWith(
          meta: testAudioEntry.meta.copyWith(
            id: 'unreadable',
            categoryId: categoryMindfulness.id,
            private: false,
          ),
          entryText: null,
          data: testAudioEntry.data.copyWith(transcripts: []),
        );
        final source = QuerySourceRef(
          id: 'unreadable',
          private: false,
          categoryPrivate: false,
          categoryId: categoryMindfulness.id,
        );
        events.addAll([
          event(
            'question',
            'feeder',
            const QueryChatEventData.question(text: 'Feeder decision?'),
          ),
          event(
            'reply',
            'feeder',
            QueryChatEventData.answer(
              questionId: 'question',
              text: 'Some recordings could not be read.',
              dependencies: [source],
              coverage: QueryCoverage(
                checked: 2,
                homeChecked: 2,
                categoryChecked: 0,
                incomplete: true,
                missingTranscripts: 1,
                unreadableSources: [source],
              ),
            ),
          ),
        ]);
        await pump(
          tester,
          sourceDetailLoading: true,
          sourceDetailId: 'unreadable',
        );
        await tester.tap(find.text('What was searched'));
        await tester.pumpAndSettle();
        expect(find.text('Home scope · Sources checked: 2'), findsOneWidget);
        final action = find.text(
          'No searchable text when this answer was written. Open the recording to inspect it.',
        );
        await tester.ensureVisible(action);
        await tester.pump();
        if (hideSource) {
          final entry = bench.entries['unreadable']!;
          bench.entries['unreadable'] = entry.copyWith(
            meta: entry.meta.copyWith(private: true),
          );
          // Deliberately do not publish a new view snapshot before the tap.
        }
        await tester.tap(action);
        await tester.pump();
        await tester.pump();
        expect(
          find.byType(EntryDetailsPage),
          hideSource ? findsNothing : findsOneWidget,
        );
        if (!hideSource) {
          await tester.tap(find.byIcon(LottiIcons.back).first);
          await tester.pump();
          expect(
            find.text('Some recordings could not be read.'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
