import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/query/query_transcription_provider.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/query/query_chat_pane.dart';
import 'package:lotti/features/agents/ui/query/query_companion.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
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
  const chatKey = (agentId: 'agent', scope: scope);
  const detailKey = Key('retained-task');
  late TranscriptEmittingController recorder;
  late ProviderContainer container;
  late FocusNode taskFocus;

  setUp(() async {
    await setUpTestGetIt();
    recorder = TranscriptEmittingController();
    taskFocus = FocusNode();
  });
  tearDown(() async {
    taskFocus.dispose();
    await tearDownTestGetIt();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    MediaQueryData? mediaQueryData,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bench = QueryTestBench();
    bench.entries['task'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'task',
        categoryId: categoryMindfulness.id,
      ),
    );
    final store = MockQueryChatStore();
    when(() => store.markRead(any(), any(), any())).thenAnswer((_) async {});
    final snapshot = QueryChatData(
      projection: QueryChatProjection([
        AgentQueryChatEventEntity(
          id: 'created',
          agentId: 'agent',
          chatId: 'feeder',
          data: const QueryChatEventData.created(
            scope: scope,
            title: 'Feeder calibration',
          ),
          createdAt: DateTime(2026, 9, 12),
          vectorClock: null,
        ),
      ]),
      access: QueryAccessSnapshot(
        showPrivate: false,
        categories: {for (final c in bench.categories) c.id: c},
        entries: {...bench.entries},
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        QueryCompanion(
          scope: scope,
          child: Focus(
            focusNode: taskFocus,
            child: const SizedBox.expand(key: detailKey),
          ),
        ),
        mediaQueryData: mediaQueryData,
        overrides: [
          queryChatTargetProvider(scope).overrideWith(
            (ref) async => QueryChatTarget(
              scope: scope,
              label: 'Inspect orbital penguin habitat',
              agent: makeTestIdentity(
                id: 'agent',
                agentId: 'agent',
                displayName: 'Habitat Watcher',
              ),
              categoryId: categoryMindfulness.id,
              categoryLabel: categoryMindfulness.name,
            ),
          ),
          queryChatStoreProvider.overrideWithValue(store),
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          queryChatDataProvider(
            chatKey,
          ).overrideWith((ref) => Stream.value(snapshot)),
          queryTranscriptionTargetResolverProvider(scope).overrideWithValue(
            () async => throw StateError('No recording submitted'),
          ),
          configFlagProvider(
            'private',
          ).overrideWith((ref) => Stream.value(false)),
          chatRecorderControllerProvider.overrideWith(
            () => recorder = TranscriptEmittingController(),
          ),
        ],
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(QueryCompanion)),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    container.read(queryPaneOpenProvider(scope).notifier).open = true;
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    tester.widget<QueryChatPane>(find.byType(QueryChatPane)).onClose();
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'docks beside the same detail and restores its width and focus on close',
    (tester) async {
      await pump(tester);
      final detail = tester.element(find.byKey(detailKey));
      taskFocus.requestFocus();
      await tester.pump();
      await open(tester);
      final task = tester.getRect(find.byKey(detailKey));
      final chat = tester.getRect(find.byType(QueryChatPane));
      expect(task.right, lessThan(chat.left));
      expect(chat.width, 400);
      expect(tester.element(find.byKey(detailKey)), same(detail));
      expect(taskFocus.hasFocus, isFalse);
      await close(tester);
      expect(tester.getSize(find.byKey(detailKey)).width, 1400);
      expect(taskFocus.hasFocus, isTrue);
      expect(tester.element(find.byKey(detailKey)), same(detail));
    },
  );

  testWidgets(
    'resizes within reading limits and preserves the chosen width across close',
    (tester) async {
      await pump(tester);
      await open(tester);
      tester
          .widget<ResizableDivider>(find.byType(ResizableDivider))
          .onDrag(100);
      await tester.pump();
      expect(tester.getSize(find.byType(QueryChatPane)).width, 500);
      await close(tester);
      await open(tester);
      expect(tester.getSize(find.byType(QueryChatPane)).width, 500);
      final divider = tester.widget<ResizableDivider>(
        find.byType(ResizableDivider),
      );
      divider.onDrag(10000);
      await tester.pump();
      expect(
        tester.getSize(find.byType(QueryChatPane)).width,
        divider.maxValue,
      );
      tester
          .widget<ResizableDivider>(find.byType(ResizableDivider))
          .onDrag(-10000);
      await tester.pump();
      expect(
        tester.getSize(find.byType(QueryChatPane)).width,
        divider.minValue,
      );
    },
  );

  testWidgets(
    'phone sheet expands and collapses while retaining the task and chat state',
    (tester) async {
      await pump(tester, size: const Size(390, 844));
      final detail = tester.element(find.byKey(detailKey));
      await open(tester);
      final chat = tester.state(find.byType(QueryChatPane));
      // A real downward drag cannot shrink the fixed header/composer into
      // Flutter's default quarter-height detent.
      await tester.drag(find.text(testTask.data.title), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(QueryChatPane)).top, closeTo(422, 1));
      tester
          .widget<QueryChatPane>(find.byType(QueryChatPane))
          .onToggleExpanded!();
      await tester.pump();
      await tester.pump(MotionDurations.medium2);
      await tester.pump();
      expect(tester.getRect(find.byType(QueryChatPane)).top, closeTo(0, 1));
      expect(
        tester.widget<QueryChatPane>(find.byType(QueryChatPane)).expanded,
        isTrue,
      );
      tester
          .widget<QueryChatPane>(find.byType(QueryChatPane))
          .onToggleExpanded!();
      await tester.pump();
      await tester.pump(MotionDurations.medium2);
      await tester.pump();
      expect(tester.getRect(find.byType(QueryChatPane)).top, closeTo(422, 1));
      expect(tester.state(find.byType(QueryChatPane)), same(chat));
      expect(tester.element(find.byKey(detailKey)), same(detail));
    },
  );

  testWidgets(
    'keyboard uses the available phone height and cannot drag below its reading area',
    (tester) async {
      await pump(
        tester,
        size: const Size(320, 844),
        mediaQueryData: const MediaQueryData(
          size: Size(320, 844),
          viewInsets: EdgeInsets.only(bottom: 240),
          textScaler: TextScaler.linear(1.5),
        ),
      );
      await open(tester);
      final before = tester.getRect(find.byType(QueryChatPane));
      expect(before.top, 0);
      expect(
        tester
            .widget<QueryChatPane>(find.byType(QueryChatPane))
            .onToggleExpanded,
        isNull,
      );
      await tester.drag(find.text(testTask.data.title), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(QueryChatPane)), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'window resize keeps the same chat and detail, and close retains the draft',
    (tester) async {
      await pump(tester);
      await open(tester);
      final chat = tester.state(find.byType(QueryChatPane));
      final detail = tester.element(find.byKey(detailKey));
      container
          .read(queryChatControllerProvider(chatKey).notifier)
          .updateDraft('feeder', 'Keep this question');
      await tester.binding.setSurfaceSize(const Size(700, 900));
      await tester.pump();
      expect(tester.state(find.byType(QueryChatPane)), same(chat));
      expect(tester.element(find.byKey(detailKey)), same(detail));
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pump();
      expect(tester.state(find.byType(QueryChatPane)), same(chat));
      await close(tester);
      container.read(chatRecorderControllerProvider.notifier);
      recorder.emitTranscript('An unrelated recording');
      await tester.pump();
      await open(tester);
      expect(
        container
            .read(queryChatControllerProvider(chatKey))
            .chats['feeder']
            ?.draft,
        'Keep this question',
      );
    },
  );
}
