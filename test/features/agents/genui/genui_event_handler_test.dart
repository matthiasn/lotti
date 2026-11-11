import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const surfaceId = 'surface-1';
  late EvolutionSurfaces processor;
  late MockDomainLogger mockDomainLogger;
  late GenUiEventHandler handler;

  setUp(() {
    processor = EvolutionSurfaces(catalogs: [buildEvolutionCatalog()])
      ..processMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': surfaceId,
            'catalogId': evolutionCatalogId,
          },
        },
      ]);
    mockDomainLogger = MockDomainLogger();
    handler = GenUiEventHandler(
      domainLogger: mockDomainLogger,
      processor: processor,
    )..listen();
  });

  tearDown(() {
    handler.dispose();
    processor.dispose();
  });

  /// Sends the action [name] from the surface, as a component's widget does.
  Future<void> act(String name, [Map<String, Object?>? context]) => processor
      .model
      .getSurface(surfaceId)!
      .dispatchAction({'name': name, 'context': ?context}, 'root');

  group('proposals', () {
    for (final name in ['proposal_approved', 'proposal_rejected']) {
      test('$name goes to the proposal callback, with its surface', () async {
        final events = <(String, String)>[];
        final soul = <(String, String)>[];
        handler
          ..onProposalAction = ((id, action) => events.add((id, action)))
          ..onSoulProposalAction = ((id, action) => soul.add((id, action)));

        await act(name);

        expect(events, [(surfaceId, name)]);
        expect(soul, isEmpty);
      });
    }

    for (final name in ['soul_proposal_approved', 'soul_proposal_rejected']) {
      test('$name goes to the soul callback only', () async {
        final events = <(String, String)>[];
        final soul = <(String, String)>[];
        handler
          ..onProposalAction = ((id, action) => events.add((id, action)))
          ..onSoulProposalAction = ((id, action) => soul.add((id, action)));

        await act(name);

        expect(soul, [(surfaceId, name)]);
        expect(events, isEmpty);
      });
    }

    test('an action no callback is set for, or of an unknown name, does '
        'nothing', () async {
      await act('proposal_approved');
      await act('soul_proposal_approved');
      await act('ratings_submitted', {
        'ratings': {'accuracy': 4},
      });
      await act('binary_choice_submitted', {'value': 'Yes'});
      await act('ab_comparison_submitted', {'value': 'A'});

      final events = <(String, String)>[];
      handler.onProposalAction = (id, action) => events.add((id, action));
      await act('some_other_event');

      expect(events, isEmpty);
      verifyNever(
        () => mockDomainLogger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
          errorType: any(named: 'errorType'),
        ),
      );
    });

    test('a callback that throws is logged without the choice, and the '
        'next action still arrives', () async {
      var calls = 0;
      handler.onBinaryChoiceSubmitted = (_, _) {
        calls++;
        if (calls == 1) throw const FormatException('bad', 'the secret choice');
      };

      await act('binary_choice_submitted', {'value': 'the secret choice'});
      await act('binary_choice_submitted', {'value': 'again'});

      expect(calls, 2);
      final logged = verify(
        () => mockDomainLogger.error(
          LogDomain.agentWorkflow,
          captureAny(),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'GenUiEventHandler',
          message: 'Failed to handle surface action binary_choice_submitted',
          errorType: FormatException,
        ),
      ).captured.single;
      expect('$logged', isNot(contains('the secret choice')));
    });

    test('dispose stops listening', () async {
      final events = <(String, String)>[];
      handler
        ..onProposalAction = ((id, action) => events.add((id, action)))
        ..dispose();

      await act('proposal_approved');

      expect(events, isEmpty);
    });

    test('listen twice delivers each action once', () async {
      final events = <(String, String)>[];
      handler
        ..onProposalAction = ((id, action) => events.add((id, action)))
        ..listen();

      await act('proposal_approved');

      expect(events, hasLength(1));
    });
  });

  group('ratings', () {
    test('arrive as whole numbers by category, a non-number as 0', () async {
      final events = <(String, Map<String, int>)>[];
      handler.onRatingsSubmitted = (id, ratings) => events.add((id, ratings));

      await act('ratings_submitted', {
        'ratings': {'accuracy': 4, 'tone': 2.0, 'odd': 'five'},
      });

      // A record holding a map compares the map by identity.
      expect(events.single.$1, surfaceId);
      expect(events.single.$2, {'accuracy': 4, 'tone': 2, 'odd': 0});
    });

    test('without a ratings map nothing is submitted', () async {
      final events = <(String, Map<String, int>)>[];
      handler.onRatingsSubmitted = (id, ratings) => events.add((id, ratings));

      await act('ratings_submitted');
      await act('ratings_submitted', {'ratings': 'four'});

      expect(events, isEmpty);
    });
  });

  group('choices', () {
    test('a binary choice arrives trimmed', () async {
      final events = <(String, String)>[];
      handler.onBinaryChoiceSubmitted = (id, value) => events.add((id, value));

      await act('binary_choice_submitted', {'value': '  Yes, show it.  '});

      expect(events, [(surfaceId, 'Yes, show it.')]);
    });

    test('an A/B pick arrives trimmed', () async {
      final events = <(String, String)>[];
      handler.onABComparisonSubmitted = (id, value) => events.add((id, value));

      await act('ab_comparison_submitted', {'value': ' Option A '});

      expect(events, [(surfaceId, 'Option A')]);
    });

    test('a blank, missing or non-text value submits nothing', () async {
      final events = <String>[];
      handler
        ..onBinaryChoiceSubmitted = ((_, value) => events.add(value))
        ..onABComparisonSubmitted = ((_, value) => events.add(value));

      for (final name in [
        'binary_choice_submitted',
        'ab_comparison_submitted',
      ]) {
        await act(name);
        await act(name, {'value': '   '});
        await act(name, {'value': 7});
      }

      expect(events, isEmpty);
    });
  });
}
