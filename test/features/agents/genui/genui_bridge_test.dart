import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  late EvolutionSurfaces processor;
  late GenUiBridge bridge;

  setUp(() {
    final catalog = buildEvolutionCatalog();
    processor = EvolutionSurfaces(catalogs: [catalog]);
    bridge = GenUiBridge(processor: processor);
  });

  group('isGenUiTool', () {
    test('returns true for render_surface', () {
      expect(bridge.isGenUiTool('render_surface'), isTrue);
    });

    test('returns false for other tool names', () {
      expect(bridge.isGenUiTool('propose_directives'), isFalse);
      expect(bridge.isGenUiTool('record_evolution_note'), isFalse);
      expect(bridge.isGenUiTool(''), isFalse);
    });
  });

  group('toolDefinition', () {
    test('has correct name and type', () {
      final tool = bridge.toolDefinition;
      expect(tool.function.name, 'render_surface');
      expect(tool.type, ChatCompletionToolType.function);
    });

    test('includes required parameters in schema', () {
      final params = bridge.toolDefinition.function.parameters!;
      final required = params['required'] as List<dynamic>;
      expect(required, containsAll(['surfaceId', 'rootType', 'data']));
    });

    test('rootType enum contains all catalog item names', () {
      final params = bridge.toolDefinition.function.parameters!;
      final properties = params['properties'] as Map<String, dynamic>;
      final rootType = properties['rootType'] as Map<String, dynamic>;
      final enumValues = rootType['enum'] as List<dynamic>;

      // The enum lists types the LLM can render directly via render_surface.
      // Auto-rendered types like SoulProposal are handled by the strategy
      // internally and don't need to be in the LLM's tool enum.
      expect(
        enumValues,
        containsAll([
          'EvolutionProposal',
          'EvolutionNoteConfirmation',
          'MetricsSummary',
          'VersionComparison',
          'CategoryRatings',
          'BinaryChoicePrompt',
          'HighPriorityFeedback',
        ]),
      );
    });
  });

  group('handleToolCall', () {
    test('returns the surfaceId from args', () {
      final id = bridge.handleToolCall({
        'surfaceId': 'test-surface-1',
        'rootType': 'MetricsSummary',
        'data': {
          'totalWakes': 10,
          'successRate': 0.8,
          'failureCount': 2,
        },
      });

      expect(id, 'test-surface-1');
    });

    test('adds surfaceId to pending list', () {
      expect(bridge.drainPendingSurfaceIds(), isEmpty);

      bridge
        ..handleToolCall({
          'surfaceId': 'surface-a',
          'rootType': 'MetricsSummary',
          'data': {'totalWakes': 1, 'successRate': 1.0, 'failureCount': 0},
        })
        ..handleToolCall({
          'surfaceId': 'surface-b',
          'rootType': 'EvolutionNoteConfirmation',
          'data': {'kind': 'reflection', 'content': 'A note'},
        });

      final ids = bridge.drainPendingSurfaceIds();
      expect(ids, ['surface-a', 'surface-b']);
    });

    test('a surface the model did not name gets an id of its own, so two '
        'never collide', () {
      const metrics = {'totalWakes': 1, 'successRate': 1.0, 'failureCount': 0};
      final first = bridge.handleToolCall({
        'rootType': 'MetricsSummary',
        'data': metrics,
      });
      final second = bridge.handleToolCall({
        'surfaceId': '',
        'rootType': 'MetricsSummary',
        'data': metrics,
      });

      expect(first, isNot(second));
      expect(bridge.drainPendingSurfaceIds(), [first, second]);
      expect(processor.model.getSurface(first), isNotNull);
      expect(processor.model.getSurface(second), isNotNull);
    });

    test('a type of its catalog that the tool enum omits is still drawn', () {
      // SessionProgress is in the evolution catalog, so the
      // bridge draws it even though the LLM-facing enum omits it.
      final id = bridge.handleToolCall({
        'surfaceId': 'surf-progress',
        'rootType': 'SessionProgress',
        'data': {
          'sessionNumber': 2,
          'totalSessions': 5,
          'feedbackCount': 3,
          'status': 'active',
        },
      });

      expect(
        processor.model.getSurface(id)!.componentsModel.get('root')!.type,
        'SessionProgress',
      );
    });

    test('a null property is one not given: a proposal that leaves out its '
        'optional parts is still drawn', () {
      final id = bridge.handleToolCall({
        'surfaceId': 'proposal-1',
        'rootType': 'EvolutionProposal',
        'data': {
          'generalDirective': 'Be brief.',
          'reportDirective': 'Lead with the outcome.',
          'rationale': 'Reports ran long.',
          'currentGeneralDirective': null,
          'currentReportDirective': null,
        },
      });

      expect(processor.model.getSurface(id), isNotNull);
      expect(bridge.drainPendingSurfaceIds(), ['proposal-1']);
    });

    test('a surface named again is replaced, not doubled', () {
      const first = {'totalWakes': 1, 'successRate': 1.0, 'failureCount': 0};
      const second = {'kind': 'reflection', 'content': 'A note'};
      bridge
        ..handleToolCall({
          'surfaceId': 'surf-again',
          'rootType': 'MetricsSummary',
          'data': first,
        })
        ..handleToolCall({
          'surfaceId': 'surf-again',
          'rootType': 'EvolutionNoteConfirmation',
          'data': second,
        });

      expect(
        processor.model
            .getSurface('surf-again')!
            .componentsModel
            .get('root')!
            .type,
        'EvolutionNoteConfirmation',
      );
      // Announced once: the chat already shows it, and it redraws itself.
      expect(bridge.drainPendingSurfaceIds(), ['surf-again']);
    });

    test('a replacement its schema refuses leaves the card already on '
        'screen as it was', () {
      bridge
        ..handleToolCall({
          'surfaceId': 'surf-kept',
          'rootType': 'EvolutionNoteConfirmation',
          'data': {'kind': 'reflection', 'content': 'A note'},
        })
        ..drainPendingSurfaceIds();

      expect(
        () => bridge.handleToolCall({
          'surfaceId': 'surf-kept',
          'rootType': 'MetricsSummary',
          'data': <String, dynamic>{},
        }),
        throwsA(isA<GenUiBridgeException>()),
      );

      final root = processor.model
          .getSurface('surf-kept')!
          .componentsModel
          .get('root')!;
      expect(root.type, 'EvolutionNoteConfirmation');
      expect(root.properties['content'], 'A note');
      expect(bridge.drainPendingSurfaceIds(), isEmpty);
    });

    group('draws nothing, and says why, for', () {
      Matcher refused(String reason) => throwsA(
        isA<GenUiBridgeException>()
            .having((e) => e.message, 'message', contains(reason))
            .having((e) => e.toString(), 'toString', contains(reason)),
      );

      test('a rootType the catalog does not have, never another type', () {
        expect(
          () => bridge.handleToolCall({
            'surfaceId': 'surf-unknown-root',
            'rootType': 'TotallyUnknownType',
            'data': <String, dynamic>{},
          }),
          refused('rootType "TotallyUnknownType" is not a widget type'),
        );
        expect(
          () => bridge.handleToolCall(<String, dynamic>{}),
          refused('rootType "null" is not a widget type'),
        );
        expect(processor.model.getSurface('surf-unknown-root'), isNull);
        expect(bridge.drainPendingSurfaceIds(), isEmpty);
      });

      test('properties its schema refuses, naming each one', () {
        expect(
          () => bridge.handleToolCall({
            'surfaceId': 'surf-empty',
            'rootType': 'MetricsSummary',
          }),
          refused('Required property "totalWakes" is missing'),
        );
        expect(
          () => bridge.handleToolCall({
            'surfaceId': 'surf-typed',
            'rootType': 'MetricsSummary',
            'data': {
              'totalWakes': 'many',
              'successRate': 1.0,
              'failureCount': 0,
            },
          }),
          refused("does not match the 'MetricsSummary' schema"),
        );
        expect(processor.model.getSurface('surf-empty'), isNull);
        expect(processor.model.getSurface('surf-typed'), isNull);
        expect(bridge.drainPendingSurfaceIds(), isEmpty);
      });

      test('data that is not an object of its properties', () {
        expect(
          () => bridge.handleToolCall({
            'surfaceId': 'surf-bad',
            'rootType': 'MetricsSummary',
            'data': 'not a map',
          }),
          refused('data must be an object of the MetricsSummary properties'),
        );
        expect(processor.model.getSurface('surf-bad'), isNull);
      });
    });
  });

  group('drainPendingSurfaceIds', () {
    test('clears the list after draining', () {
      bridge.handleToolCall({
        'surfaceId': 'surf-1',
        'rootType': 'MetricsSummary',
        'data': {'totalWakes': 0, 'successRate': 0.0, 'failureCount': 0},
      });

      final first = bridge.drainPendingSurfaceIds();
      expect(first, hasLength(1));

      final second = bridge.drainPendingSurfaceIds();
      expect(second, isEmpty);
    });

    test('returns independent copies', () {
      bridge.handleToolCall({
        'surfaceId': 'surf-1',
        'rootType': 'MetricsSummary',
        'data': {'totalWakes': 0, 'successRate': 0.0, 'failureCount': 0},
      });

      final first = bridge.drainPendingSurfaceIds();

      bridge.handleToolCall({
        'surfaceId': 'surf-2',
        'rootType': 'MetricsSummary',
        'data': {'totalWakes': 0, 'successRate': 0.0, 'failureCount': 0},
      });

      final second = bridge.drainPendingSurfaceIds();

      // Mutating one list should not affect the other.
      expect(first, ['surf-1']);
      expect(second, ['surf-2']);
    });
  });
}
