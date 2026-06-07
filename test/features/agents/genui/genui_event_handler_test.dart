import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late SurfaceController processor;
  late GenUiBridge bridge;
  late GenUiEventHandler handler;

  setUp(() {
    final catalog = buildEvolutionCatalog();
    processor = SurfaceController(catalogs: [catalog]);
    bridge = GenUiBridge(processor: processor);
    handler = GenUiEventHandler(processor: processor)..listen();
  });

  tearDown(() {
    handler.dispose();
  });

  /// Dispatches a UserActionEvent through the processor's handleUiEvent
  /// (which converts it to a ChatMessage with UiInteractionPart on the
  /// onSubmit stream) and waits for the async broadcast delivery.
  Future<void> dispatchAndWait({
    required String name,
    required String surfaceId,
    String sourceComponentId = 'root',
  }) async {
    processor.handleUiEvent(
      UserActionEvent(
        name: name,
        sourceComponentId: sourceComponentId,
        surfaceId: surfaceId,
      ),
    );
    await pumpEventQueue();
  }

  group('GenUiEventHandler', () {
    test('routes proposal_approved event to callback', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      await dispatchAndWait(
        name: 'proposal_approved',
        surfaceId: 'proposal-surface',
      );

      expect(events, hasLength(1));
      expect(events.first.$1, 'proposal-surface');
      expect(events.first.$2, 'proposal_approved');
    });

    test('routes proposal_rejected event to callback', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      await dispatchAndWait(
        name: 'proposal_rejected',
        surfaceId: 'proposal-surface-2',
      );

      expect(events, hasLength(1));
      expect(events.first.$2, 'proposal_rejected');
    });

    test('keeps listening after a proposal callback throws', () async {
      handler.onProposalAction = (_, _) => throw StateError('callback failed');

      await dispatchAndWait(
        name: 'proposal_approved',
        surfaceId: 'proposal-surface',
      );

      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      await dispatchAndWait(
        name: 'proposal_rejected',
        surfaceId: 'proposal-surface',
      );

      expect(events, [('proposal-surface', 'proposal_rejected')]);
    });

    test('keeps listening after a malformed interaction part throws', () async {
      final submitController = StreamController<ChatMessage>.broadcast();
      addTearDown(submitController.close);

      final mockProcessor = MockSurfaceController();
      when(() => mockProcessor.onSubmit).thenAnswer(
        (_) => submitController.stream,
      );

      final malformedHandler = GenUiEventHandler(processor: mockProcessor)
        ..listen();
      addTearDown(malformedHandler.dispose);

      final events = <(String, String)>[];
      malformedHandler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      submitController.add(
        ChatMessage.user(
          '',
          parts: [
            DataPart(
              Uint8List.fromList([0xff]),
              mimeType: UiPartConstants.interactionMimeType,
            ),
          ],
        ),
      );
      await pumpEventQueue();

      submitController.add(
        ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(
              jsonEncode({
                'version': 'v0.9',
                'action': UserActionEvent(
                  name: 'proposal_approved',
                  sourceComponentId: 'root',
                  surfaceId: 'proposal-surface',
                ).toMap(),
              }),
            ),
          ],
        ),
      );
      await pumpEventQueue();

      expect(events, [('proposal-surface', 'proposal_approved')]);
    });

    test('ignores non-proposal events', () async {
      final events = <(String, String)>[];
      handler.onProposalAction = (surfaceId, action) {
        events.add((surfaceId, action));
      };

      await dispatchAndWait(
        name: 'some_other_event',
        surfaceId: 'any-surface',
      );

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

      await dispatchAndWait(
        name: 'proposal_approved',
        surfaceId: 'proposal-surface-3',
      );
      // No exception = pass.
    });

    test('dispose stops listening for events', () async {
      final events = <(String, String)>[];
      handler
        ..onProposalAction = (surfaceId, action) {
          events.add((surfaceId, action));
        }
        ..dispose();

      await dispatchAndWait(
        name: 'proposal_approved',
        surfaceId: 'some-surface',
      );

      expect(events, isEmpty);
    });

    test('routes ratings_submitted event to callback', () async {
      final events = <(String, Map<String, int>)>[];
      handler.onRatingsSubmitted = (surfaceId, ratings) {
        events.add((surfaceId, ratings));
      };

      await dispatchAndWait(
        name: 'ratings_submitted',
        surfaceId: 'ratings-surface',
        sourceComponentId: '{"accuracy":5,"tooling":"bad","timeliness":2.2}',
      );

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

      await dispatchAndWait(
        name: 'ratings_submitted',
        surfaceId: 'ratings-surface',
        sourceComponentId: '{invalid-json',
      );

      expect(events, isEmpty);
    });

    test('routes binary_choice_submitted event to callback', () async {
      final events = <(String, String)>[];
      handler.onBinaryChoiceSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      await dispatchAndWait(
        name: 'binary_choice_submitted',
        surfaceId: 'binary-choice-surface',
        sourceComponentId: '{"value":"Yes, show the rating form."}',
      );

      expect(events, hasLength(1));
      expect(events.first.$1, 'binary-choice-surface');
      expect(events.first.$2, 'Yes, show the rating form.');
    });

    test('ignores malformed binary choice JSON', () async {
      final events = <(String, String)>[];
      handler.onBinaryChoiceSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      await dispatchAndWait(
        name: 'binary_choice_submitted',
        surfaceId: 'binary-choice-surface',
        sourceComponentId: '{bad-json',
      );

      expect(events, isEmpty);
    });

    test(
      'ignores binary_choice_submitted when the payload value is not a '
      'String',
      () async {
        final events = <(String, String)>[];
        handler.onBinaryChoiceSubmitted = (surfaceId, value) {
          events.add((surfaceId, value));
        };

        await dispatchAndWait(
          name: 'binary_choice_submitted',
          surfaceId: 'binary-surface',
          sourceComponentId: '{"value": 42}',
        );

        // The non-String value falls through silently — no callback.
        expect(events, isEmpty);
      },
    );
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

      await dispatchAndWait(
        name: 'soul_proposal_approved',
        surfaceId: 'soul-surface-1',
      );

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

      await dispatchAndWait(
        name: 'soul_proposal_rejected',
        surfaceId: 'soul-surface-2',
      );

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

      await dispatchAndWait(
        name: 'soul_proposal_approved',
        surfaceId: 'soul-surface-3',
      );
      expect(events, isEmpty);
    });
  });

  group('AB comparison events', () {
    test('routes ab_comparison_submitted to callback', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      await dispatchAndWait(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-1',
        sourceComponentId: '{"value":"I prefer Option A — Warmer"}',
      );

      expect(events, hasLength(1));
      expect(events.first.$1, 'ab-surface-1');
      expect(events.first.$2, 'I prefer Option A — Warmer');
    });

    test('ignores malformed AB comparison JSON', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      await dispatchAndWait(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-2',
        sourceComponentId: '{bad-json',
      );

      expect(events, isEmpty);
    });

    test('ignores empty value in AB comparison', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (surfaceId, value) {
        events.add((surfaceId, value));
      };

      await dispatchAndWait(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-3',
        sourceComponentId: '{"value":"  "}',
      );

      expect(events, isEmpty);
    });

    test('does not fire when callback is null', () async {
      // Register a callback, then clear it — verify no invocation after.
      final recordedEvents = <(String, String)>[];
      handler
        ..onABComparisonSubmitted = (surfaceId, value) {
          recordedEvents.add((surfaceId, value));
        }
        ..onABComparisonSubmitted = null;

      await dispatchAndWait(
        name: 'ab_comparison_submitted',
        surfaceId: 'ab-surface-4',
        sourceComponentId: '{"value":"I prefer Option B"}',
      );

      expect(recordedEvents, isEmpty);
    });
  });
}
