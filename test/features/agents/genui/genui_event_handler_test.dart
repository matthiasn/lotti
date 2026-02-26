import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';

void main() {
  late A2uiMessageProcessor processor;
  late GenUiBridge bridge;
  late GenUiEventHandler handler;

  setUp(() {
    final catalog = buildEvolutionCatalog();
    processor = A2uiMessageProcessor(catalogs: [catalog]);
    bridge = GenUiBridge(processor: processor);
    handler = GenUiEventHandler(processor: processor)..listen();
  });

  tearDown(() {
    handler.dispose();
  });

  /// Helper to dispatch a UserActionEvent through the processor's handleUiEvent,
  /// which converts it to a JSON-encoded UserUiInteractionMessage on the
  /// onSubmit stream.
  void dispatchAction({
    required String name,
    required String surfaceId,
    String sourceComponentId = 'root',
  }) {
    processor.handleUiEvent(
      UserActionEvent(
        name: name,
        sourceComponentId: sourceComponentId,
        surfaceId: surfaceId,
      ),
    );
  }

  group('GenUiEventHandler', () {
    test('routes proposal_approved event to callback', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      // Create a surface so the processor knows about it.
      bridge.handleToolCall({
        'surfaceId': 'proposal-surface',
        'rootType': 'EvolutionProposal',
        'data': {
          'directives': 'Be concise.',
          'rationale': 'Users prefer brevity.',
        },
      });

      dispatchAction(
        name: 'proposal_approved',
        surfaceId: 'proposal-surface',
      );

      // Allow the stream to deliver the event.
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.$1, 'proposal-surface');
      expect(events.first.$2, 'proposal_approved');
    });

    test('routes proposal_rejected event to callback', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      bridge.handleToolCall({
        'surfaceId': 'proposal-surface-2',
        'rootType': 'EvolutionProposal',
        'data': {
          'directives': 'Be verbose.',
          'rationale': 'More detail is better.',
        },
      });

      dispatchAction(
        name: 'proposal_rejected',
        surfaceId: 'proposal-surface-2',
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.$2, 'proposal_rejected');
    });

    test('ignores non-proposal events', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      dispatchAction(
        name: 'some_other_event',
        surfaceId: 'any-surface',
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('does not call callback when onProposalAction is null', () async {
      // No callback set — should not throw.
      bridge.handleToolCall({
        'surfaceId': 'proposal-surface-3',
        'rootType': 'EvolutionProposal',
        'data': {
          'directives': 'Test.',
          'rationale': 'Test.',
        },
      });

      dispatchAction(
        name: 'proposal_approved',
        surfaceId: 'proposal-surface-3',
      );

      await Future<void>.delayed(Duration.zero);
      // No exception = pass.
    });

    test('dispose stops listening for events', () async {
      final events = <(String, String)>[];
      handler
        ..onProposalAction = (surfaceId, action) {
          events.add((surfaceId, action));
        }
        ..dispose();

      dispatchAction(
        name: 'proposal_approved',
        surfaceId: 'some-surface',
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });
  });
}
