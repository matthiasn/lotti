import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  late A2uiMessageProcessor processor;
  late GenUiBridge bridge;

  setUp(() {
    final catalog = buildEvolutionCatalog();
    processor = A2uiMessageProcessor(catalogs: [catalog]);
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

      expect(
        enumValues,
        containsAll([
          'EvolutionProposal',
          'EvolutionNoteConfirmation',
          'MetricsSummary',
          'VersionComparison',
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

    test('uses defaults for missing args', () {
      final id = bridge.handleToolCall(<String, dynamic>{});
      expect(id, 'surface-unknown');
    });

    test('handles non-map data gracefully', () {
      // Simulate malformed LLM output where data is a string instead of map.
      final id = bridge.handleToolCall({
        'surfaceId': 'surf-bad',
        'rootType': 'MetricsSummary',
        'data': 'not a map',
      });
      expect(id, 'surf-bad');
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
