import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  final date = DateTime(2026, 6, 15);

  AiResponseEntry aiResponse({String id = 'ai-1'}) => AiResponseEntry(
    meta: TestMetadataFactory.create(id: id, createdAt: date),
    data: const AiResponseData(
      model: '',
      systemMessage: '',
      prompt: '',
      thoughts: '',
      response: '',
    ),
  );

  EntryLink basic() => EntryLink.basic(
    id: 'l',
    fromId: 'a',
    toId: 'b',
    createdAt: date,
    updatedAt: date,
    vectorClock: null,
  );
  EntryLink rating() => EntryLink.rating(
    id: 'l',
    fromId: 'a',
    toId: 'b',
    createdAt: date,
    updatedAt: date,
    vectorClock: null,
  );
  EntryLink project() => EntryLink.project(
    id: 'l',
    fromId: 'a',
    toId: 'b',
    createdAt: date,
    updatedAt: date,
    vectorClock: null,
  );

  group('graphNodeTypeFor', () {
    test('maps entity variants to node types', () {
      expect(graphNodeTypeFor(TestTaskFactory.create()), GraphNodeType.task);
      expect(
        graphNodeTypeFor(TestProjectFactory.create()),
        GraphNodeType.project,
      );
      expect(
        graphNodeTypeFor(aiResponse()),
        GraphNodeType.aiResponse,
      );
    });
  });

  group('graphNodeLabelFor', () {
    test('uses the title for tasks and projects', () {
      expect(
        graphNodeLabelFor(TestTaskFactory.create(title: 'Ship v2')),
        'Ship v2',
      );
      expect(
        graphNodeLabelFor(TestProjectFactory.create(title: 'Alpha')),
        'Alpha',
      );
    });

    test('falls back when a task has no title', () {
      expect(
        graphNodeLabelFor(TestTaskFactory.create(title: '')),
        'Untitled task',
      );
    });

    test('labels AI responses generically', () {
      expect(graphNodeLabelFor(aiResponse()), 'AI summary');
    });
  });

  group('edgeKindFor', () {
    final task = TestTaskFactory.create(id: 'task');
    final other = TestTaskFactory.create(id: 'other');

    test('ProjectLink is containment', () {
      expect(edgeKindFor(project(), task, other), GraphEdgeKind.containment);
    });

    test('RatingLink is evaluation', () {
      expect(edgeKindFor(rating(), task, other), GraphEdgeKind.evaluation);
    });

    test('BasicLink between two non-AI entries is association', () {
      expect(edgeKindFor(basic(), task, other), GraphEdgeKind.association);
    });

    test('BasicLink touching an AI response is provenance', () {
      expect(
        edgeKindFor(basic(), aiResponse(), task),
        GraphEdgeKind.provenance,
      );
      expect(
        edgeKindFor(basic(), task, aiResponse()),
        GraphEdgeKind.provenance,
      );
    });
  });

  group('taskGraphProvider (FutureProvider body)', () {
    late MockJournalDb db;
    late MockEntitiesCacheService cache;
    late MockUpdateNotifications notifications;
    late MockAgentRepository agentRepo;
    late StreamController<Set<String>> updates;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      db = MockJournalDb();
      cache = MockEntitiesCacheService();
      notifications = MockUpdateNotifications();
      agentRepo = MockAgentRepository();
      updates = StreamController<Set<String>>.broadcast();

      // Sensible empty defaults — individual tests override what they care
      // about so mock setup stays small relative to assertions.
      when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
      when(() => db.journalEntityById(any())).thenAnswer((_) async => null);
      when(
        () => db.linksForEntryIdsBidirectional(any()),
      ).thenAnswer((_) async => <EntryLink>[]);
      when(() => db.getProjectForTask(any())).thenAnswer((_) async => null);
      when(
        () => db.getTasksForProject(any()),
      ).thenAnswer((_) async => <Task>[]);
      when(() => cache.getCategoryById(any())).thenReturn(null);
      // No assigned-agent reports by default — tests that care about the
      // inspector summary override this for the task ids they exercise.
      when(
        () => agentRepo.getLatestTaskReportsForTaskIds(any()),
      ).thenAnswer((_) async => const <String, AgentReportEntity>{});

      await getIt.reset();
      getIt
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton<EntitiesCacheService>(cache)
        ..registerSingleton<UpdateNotifications>(notifications)
        // getFullImagePath -> getDocumentsDirectory() -> getIt<Directory>().
        ..registerSingleton<Directory>(Directory('/docs'));
    });

    tearDown(() async {
      await updates.close();
      await getIt.reset();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(agentRepo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // Builds an assigned-agent report; trimmed-blank handling is exercised in
    // the provider, so callers pass raw oneLiner/tldr/content text here.
    AgentReportEntity report({
      required String id,
      String? oneLiner,
      String? tldr,
      String content = '',
    }) =>
        AgentDomainEntity.agentReport(
              id: id,
              agentId: 'agent-$id',
              scope: 'task',
              createdAt: date,
              vectorClock: null,
              oneLiner: oneLiner,
              tldr: tldr,
              content: content,
            )
            as AgentReportEntity;

    // Stub the bulk task-report lookup so each task id resolves to its report.
    void stubReports(Map<String, AgentReportEntity> byTaskId) {
      when(() => agentRepo.getLatestTaskReportsForTaskIds(any())).thenAnswer((
        invocation,
      ) async {
        final ids = invocation.positionalArguments.first as List<String>;
        return {
          for (final id in ids)
            if (byTaskId[id] != null) id: byTaskId[id]!,
        };
      });
    }

    // Stub a bidirectional links lookup keyed on the ids the BFS passes in,
    // so the same frontier set always resolves to the same links.
    void stubLinks(Map<String, List<EntryLink>> byId) {
      when(() => db.linksForEntryIdsBidirectional(any())).thenAnswer((
        invocation,
      ) async {
        final ids = invocation.positionalArguments.first as Set<String>;
        final result = <EntryLink>[];
        final seen = <String>{};
        for (final id in ids) {
          for (final link in byId[id] ?? const <EntryLink>[]) {
            if (seen.add(link.id)) result.add(link);
          }
        }
        return result;
      });
    }

    // Resolve entities by id from a fixed map.
    void stubEntities(Map<String, JournalEntity> entities) {
      when(() => db.journalEntityById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        return entities[id];
      });
    }

    CategoryDefinition category({
      required String id,
      required String name,
      String? color,
    }) => CategoryDefinition(
      id: id,
      name: name,
      color: color,
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    );

    JournalImage image({
      required String id,
      String text = '',
      String? categoryId,
    }) => JournalImage(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        categoryId: categoryId,
      ),
      data: ImageData(
        capturedAt: date,
        imageId: id,
        imageFile: '$id.jpg',
        imageDirectory: '/images/',
      ),
      entryText: text.isEmpty ? null : EntryText(plainText: text),
    );

    JournalEntry textEntry({required String id, String text = 'A note'}) =>
        JournalEntry(
          meta: TestMetadataFactory.create(id: id, createdAt: date),
          entryText: EntryText(plainText: text),
        );

    JournalAudio audioEntry({required String id}) => JournalAudio(
      meta: TestMetadataFactory.create(id: id, createdAt: date),
      data: AudioData(
        dateFrom: date,
        dateTo: date,
        audioFile: '$id.m4a',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 30),
      ),
    );

    AiResponseEntry aiEntry({
      required String id,
      String response = 'Ship it',
    }) => AiResponseEntry(
      meta: TestMetadataFactory.create(id: id, createdAt: date),
      data: AiResponseData(
        model: '',
        systemMessage: '',
        prompt: '',
        thoughts: '',
        response: response,
      ),
    );

    RatingEntry ratingEntry({required String id}) => RatingEntry(
      meta: TestMetadataFactory.create(id: id, createdAt: date),
      data: const RatingData(
        targetId: 'task',
        dimensions: [RatingDimension(key: 'focus', value: 0.9)],
      ),
    );

    Checklist checklist({required String id, required List<String> itemIds}) =>
        Checklist(
          meta: TestMetadataFactory.create(id: id, createdAt: date),
          data: ChecklistData(
            title: 'Checklist',
            linkedChecklistItems: itemIds,
            linkedTasks: const [],
          ),
        );

    ChecklistItem checklistItemEntity({required String id}) => ChecklistItem(
      meta: TestMetadataFactory.create(id: id, createdAt: date),
      data: TestChecklistItemFactory.create(title: 'Item $id', id: id),
    );

    EntryLink basicLink({
      required String id,
      required String fromId,
      required String toId,
    }) => EntryLink.basic(
      id: id,
      fromId: fromId,
      toId: toId,
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
    );

    test(
      'projects a task neighborhood into nodes/edges with categories, '
      'cover art, image paths and tldr',
      () async {
        // Focus task with a category and cover art, in a project with a
        // sibling task, linked to a text/audio/image/AI/rating entry, and
        // carrying a checklist with one item.
        final focus =
            TestTaskFactory.create(
              id: 'task',
              title: 'Focus task',
              categoryId: 'cat',
              checklistIds: ['cl'],
            ).copyWith(
              data: TestTaskDataFactory.create(
                title: 'Focus task',
                checklistIds: ['cl'],
              ).copyWith(coverArtId: 'cover'),
            );
        final sibling = TestTaskFactory.create(
          id: 'sibling',
          title: 'Sibling',
          categoryId: 'cat',
        );
        final project = TestProjectFactory.create(
          id: 'proj',
          title: 'Project',
          categoryId: 'cat',
        );
        final note = textEntry(id: 'note', text: 'Logged work');
        final audio = audioEntry(id: 'aud');
        final img = image(id: 'img', categoryId: 'cat');
        final ai = aiEntry(id: 'ai', response: '## TL;DR\nShip it');
        final rating = ratingEntry(id: 'rate');
        final cover = image(id: 'cover');
        final cl = checklist(id: 'cl', itemIds: ['cli']);
        final item = checklistItemEntity(id: 'cli');

        stubEntities({
          'task': focus,
          'sibling': sibling,
          'proj': project,
          'note': note,
          'aud': audio,
          'img': img,
          'ai': ai,
          'rate': rating,
          'cover': cover,
          'cl': cl,
          'cli': item,
        });
        stubLinks({
          'task': [
            basicLink(id: 'l-note', fromId: 'task', toId: 'note'),
            basicLink(id: 'l-aud', fromId: 'task', toId: 'aud'),
            basicLink(id: 'l-img', fromId: 'task', toId: 'img'),
            basicLink(id: 'l-ai', fromId: 'task', toId: 'ai'),
            EntryLink.rating(
              id: 'l-rate',
              fromId: 'rate',
              toId: 'task',
              createdAt: date,
              updatedAt: date,
              vectorClock: null,
            ),
          ],
        });
        when(
          () => db.getProjectForTask('task'),
        ).thenAnswer((_) async => project);
        when(
          () => db.getTasksForProject('proj'),
        ).thenAnswer((_) async => [focus, sibling]);
        when(
          () => cache.getCategoryById('cat'),
        ).thenReturn(category(id: 'cat', name: 'Lotti', color: '#00FF00'));
        // The focus task's assigned-agent report drives its inspector summary;
        // leading/trailing whitespace must be trimmed off.
        stubReports({
          'task': report(
            id: 'rep',
            oneLiner: '  Ship the release  ',
            tldr: '  All checks green  ',
          ),
        });

        final data = await makeContainer().read(
          taskGraphProvider('task').future,
        );

        expect(data, isNotNull);
        final scenario = data!.scenario;
        expect(scenario.seedId, 'task');
        expect(scenario.name, 'Focus task');

        final nodeTypes = {for (final n in scenario.nodes) n.id: n.type};
        expect(nodeTypes['task'], GraphNodeType.task);
        expect(nodeTypes['proj'], GraphNodeType.project);
        expect(nodeTypes['sibling'], GraphNodeType.task);
        expect(nodeTypes['note'], GraphNodeType.textEntry);
        expect(nodeTypes['aud'], GraphNodeType.audioEntry);
        expect(nodeTypes['img'], GraphNodeType.imageEntry);
        expect(nodeTypes['ai'], GraphNodeType.aiResponse);
        expect(nodeTypes['rate'], GraphNodeType.rating);
        expect(nodeTypes['cl'], GraphNodeType.checklist);
        expect(nodeTypes['cli'], GraphNodeType.checklistItem);

        // Every relation kind the classifier can produce shows up.
        bool hasEdge(String from, String to, GraphEdgeKind kind) =>
            scenario.edges.any(
              (e) => e.fromId == from && e.toId == to && e.kind == kind,
            );
        expect(hasEdge('proj', 'task', GraphEdgeKind.containment), isTrue);
        expect(hasEdge('proj', 'sibling', GraphEdgeKind.containment), isTrue);
        expect(hasEdge('task', 'note', GraphEdgeKind.association), isTrue);
        expect(hasEdge('task', 'ai', GraphEdgeKind.provenance), isTrue);
        expect(hasEdge('rate', 'task', GraphEdgeKind.evaluation), isTrue);
        expect(hasEdge('task', 'cl', GraphEdgeKind.association), isTrue);
        expect(hasEdge('cl', 'cli', GraphEdgeKind.checklist), isTrue);

        // Category colors + names map populated from the stubbed category.
        expect(data.categoryColors['cat'], const Color(0xFF00FF00));
        expect(data.categoryNames['cat'], 'Lotti');

        // Image node carries its resolved absolute path.
        final imgNode = scenario.nodes.firstWhere((n) => n.id == 'img');
        expect(imgNode.imagePath, '/docs/images/img.jpg');

        // Task cover art resolves to the linked image's path; the inspector
        // summary (oneLiner + tldr) comes from the assigned-agent report,
        // trimmed.
        final taskNode = scenario.nodes.firstWhere((n) => n.id == 'task');
        expect(taskNode.coverImagePath, '/docs/images/cover.jpg');
        expect(taskNode.oneLiner, 'Ship the release');
        expect(taskNode.tldr, 'All checks green');

        // A task without a report carries no inspector summary.
        final siblingNode = scenario.nodes.firstWhere((n) => n.id == 'sibling');
        expect(siblingNode.oneLiner, isNull);
        expect(siblingNode.tldr, isNull);

        // The AI node exposes its own response as tldr; oneLiner is task-only.
        final aiNode = scenario.nodes.firstWhere((n) => n.id == 'ai');
        expect(aiNode.tldr, '## TL;DR\nShip it');
        expect(aiNode.oneLiner, isNull);
      },
    );

    test('task tldr falls back to report content when tldr is blank', () async {
      final focus = TestTaskFactory.create(id: 'task', title: 'Focus');
      stubEntities({'task': focus});
      stubReports({
        'task': report(
          id: 'rep',
          oneLiner: '  ',
          tldr: '   ',
          content: 'Full report body',
        ),
      });

      final data = await makeContainer().read(
        taskGraphProvider('task').future,
      );

      final taskNode = data!.scenario.nodes.firstWhere((n) => n.id == 'task');
      // Blank oneLiner trims to null; blank tldr falls through to content.
      expect(taskNode.oneLiner, isNull);
      expect(taskNode.tldr, 'Full report body');
    });

    test('returns null when the focus id is not a journal entity', () async {
      // journalEntityById defaults to null for every id.
      final data = await makeContainer().read(
        taskGraphProvider('missing').future,
      );
      expect(data, isNull);
    });

    test('a focus task with no links yields a single-node scenario', () async {
      final focus = TestTaskFactory.create(id: 'lonely', title: 'Lonely');
      stubEntities({'lonely': focus});

      final data = await makeContainer().read(
        taskGraphProvider('lonely').future,
      );

      expect(data, isNotNull);
      expect(data!.scenario.nodes, hasLength(1));
      final node = data.scenario.nodes.single;
      expect(node.id, 'lonely');
      expect(data.scenario.edges, isEmpty);
      // No assigned-agent report -> no inspector summary.
      expect(node.oneLiner, isNull);
      expect(node.tldr, isNull);
      // No category stubbed -> uncategorized node -> no colors/names.
      expect(data.categoryColors, isEmpty);
      expect(data.categoryNames, isEmpty);
    });

    test(
      'uncategorized nodes get no color; missing color hex is skipped',
      () async {
        final focus = TestTaskFactory.create(id: 'task', title: 'Focus');
        final note = textEntry(id: 'note');
        stubEntities({'task': focus, 'note': note});
        stubLinks({
          'task': [basicLink(id: 'l', fromId: 'task', toId: 'note')],
        });
        // Category exists but has no color -> name maps, color does not.
        when(
          () => cache.getCategoryById(kUncategorized),
        ).thenReturn(category(id: kUncategorized, name: 'Inbox'));

        final data = await makeContainer().read(
          taskGraphProvider('task').future,
        );

        expect(data, isNotNull);
        expect(data!.categoryColors, isEmpty);
        expect(data.categoryNames[kUncategorized], 'Inbox');
      },
    );

    test('malformed category color falls back to grey', () async {
      final focus = TestTaskFactory.create(
        id: 'task',
        title: 'Focus',
        categoryId: 'cat',
      );
      stubEntities({'task': focus});
      when(
        () => cache.getCategoryById('cat'),
      ).thenReturn(category(id: 'cat', name: 'Bad', color: 'not-a-color'));

      final data = await makeContainer().read(
        taskGraphProvider('task').future,
      );

      expect(data!.categoryColors['cat'], Colors.grey);
    });

    test(
      'recomputes when the seed task changes on the update stream',
      () async {
        final focus = TestTaskFactory.create(id: 'task', title: 'Focus');
        stubEntities({'task': focus});
        final container = makeContainer();

        // Prime the provider and keep it alive (autoDispose) by listening.
        final sub = container.listen(
          taskGraphProvider('task'),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        await container.read(taskGraphProvider('task').future);
        clearInteractions(db);

        updates.add({'task'});
        await pumpEventQueue();
        await container.read(taskGraphProvider('task').future);

        // Recomputation re-loads the focus entity.
        verify(() => db.journalEntityById('task')).called(greaterThan(0));
      },
    );

    test(
      'recomputes when a loaded neighbor changes on the update stream',
      () async {
        final focus = TestTaskFactory.create(id: 'task', title: 'Focus');
        final note = textEntry(id: 'note');
        stubEntities({'task': focus, 'note': note});
        stubLinks({
          'task': [basicLink(id: 'l', fromId: 'task', toId: 'note')],
        });
        final container = makeContainer();

        final sub = container.listen(
          taskGraphProvider('task'),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final first = await container.read(taskGraphProvider('task').future);
        expect(first!.scenario.nodes.map((n) => n.id), contains('note'));
        clearInteractions(db);

        // 'note' is a loaded neighbor, not the seed — still triggers a refresh.
        updates.add({'note'});
        await pumpEventQueue();
        await container.read(taskGraphProvider('task').future);

        verify(() => db.journalEntityById('task')).called(greaterThan(0));
      },
    );

    test('ignores update events for ids outside the loaded graph', () async {
      final focus = TestTaskFactory.create(id: 'task', title: 'Focus');
      stubEntities({'task': focus});
      final container = makeContainer();

      final sub = container.listen(
        taskGraphProvider('task'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await container.read(taskGraphProvider('task').future);
      clearInteractions(db);

      // An unrelated id must NOT invalidate the provider.
      updates.add({'unrelated'});
      await pumpEventQueue();

      verifyNever(() => db.journalEntityById(any()));
    });
  });
}
