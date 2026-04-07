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
      await Future<void>.value();

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

      await Future<void>.value();

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

      await Future<void>.value();

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

      await Future<void>.value();
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

      await Future<void>.value();

      expect(events, isEmpty);
    });

    test('routes ratings_submitted event to callback', () async {
      final events = <(String, Map<String, int>)>[];
      handler.onRatingsSubmitted = (surfaceId, ratings) {
        events.add((surfaceId, ratings));
      };

      dispatchAction(
        name: 'ratings_submitted',
        surfaceId: 'ratings-surface',
        sourceComponentId: '{"accuracy":5,"tooling":"bad","timeliness":2.2}',
      );

      await Future<void>.value();

      expect(events, hasLength(1));
      expect(events.first.$1, 'ratings-surface');
      expect(events.first.$2, {
        'accuracy': 5,
        'tooling': 0,
        'timeliness': 2,
      });
    });

    test('ignores malformed ratings JSON', () async {
      final events = <(String, Map<String, int>)>[];
      handler.onRatingsSubmitted = (surfaceId, ratings) {
        events.add((surfaceId, ratings));
      };

      dispatchAction(
        name: 'ratings_submitted',
        surfaceId: 'ratings-surface',
        sourceComponentId: '{invalid-json',
      );

      await Future<void>.value();

      expect(events, isEmpty);
    });

    test('routes binary_choice_submitted event to callback', () async {
      final events = <(String, String)>[];
      handler.onBinaryChoiceSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      dispatchAction(
        name: 'binary_choice_submitted',
        surfaceId: 'binary-choice-surface',
        sourceComponentId: '{"value":"Yes, show the rating form."}',
      );

      await Future<void>.value();

      expect(events, hasLength(1));
      expect(events.first.$1, 'binary-choice-surface');
      expect(events.first.$2, 'Yes, show the rating form.');
    });

    test('ignores malformed binary choice JSON', () async {
      final events = <(String, String)>[];
      handler.onBinaryChoiceSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      dispatchAction(
        name: 'binary_choice_submitted',
        surfaceId: 'binary-choice-surface',
        sourceComponentId: '{bad-json',
      );

      await Future<void>.value();

      expect(events, isEmpty);
    });
  });

  group('soul proposal events', () {
    test('routes soul_proposal_approved to callback', () async {
      final events = <(String, String)>[];
      handler.onSoulProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      bridge.handleToolCall({
        'surfaceId': 'soul-surface-1',
        'rootType': 'SoulProposal',
        'data': {'rationale': 'Test.'},
      });

      dispatchAction(
        name: 'soul_proposal_approved',
        surfaceId: 'soul-surface-1',
      );

      await Future<void>.value();

      expect(events, hasLength(1));
      expect(events.first.$1, 'soul-surface-1');
      expect(events.first.$2, 'soul_proposal_approved');
    });

    test('routes soul_proposal_rejected to callback', () async {
      final events = <(String, String)>[];
      handler.onSoulProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      bridge.handleToolCall({
        'surfaceId': 'soul-surface-2',
        'rootType': 'SoulProposal',
        'data': {'rationale': 'Test.'},
      });

      dispatchAction(
        name: 'soul_proposal_rejected',
        surfaceId: 'soul-surface-2',
      );

      await Future<void>.value();

      expect(events, hasLength(1));
      expect(events.first.$2, 'soul_proposal_rejected');
    });

    test('does not call callback when onSoulProposalAction is null', () async {
      final events = <(String, String)>[];
      handler
        ..onSoulProposalAction = (surfaceId, action) {
          events.add((surfaceId, action));
        }
        ..onSoulProposalAction = null;

      bridge.handleToolCall({
        'surfaceId': 'soul-surface-3',
        'rootType': 'SoulProposal',
        'data': {'rationale': 'Test.'},
      });

      dispatchAction(
        name: 'soul_proposal_approved',
        surfaceId: 'soul-surface-3',
      );

      await Future<void>.value();
      expect(events, isEmpty);
    });
  });

  group('AB comparison events', () {
    test('routes ab_comparison_submitted to callback', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      dispatchAction(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-1',
        sourceComponentId: '{"value":"I prefer Option A — Warmer"}',
      );

      await Future<void>.value();

      expect(events, hasLength(1));
      expect(events.first.$1, 'ab-surface-1');
      expect(events.first.$2, 'I prefer Option A — Warmer');
    });

    test('ignores malformed AB comparison JSON', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      dispatchAction(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-2',
        sourceComponentId: '{bad-json',
      );

      await Future<void>.value();

      expect(events, isEmpty);
    });

    test('ignores empty value in AB comparison', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      dispatchAction(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-3',
        sourceComponentId: '{"value":"  "}',
      );

      await Future<void>.value();

      expect(events, isEmpty);
    });

    test('does not fire when callback is null', () async {
      // No callback registered — should not throw.
      dispatchAction(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-4',
        sourceComponentId: '{"value":"I prefer Option B"}',
      );

      await Future<void>.value();
      // No assertion needed — just verifying no exception.
    });
  });
}
