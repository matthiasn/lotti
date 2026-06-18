import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';

import '../../../helpers/entity_factories.dart';

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
}
