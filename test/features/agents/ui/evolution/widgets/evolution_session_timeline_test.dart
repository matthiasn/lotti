import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)? sessionsOverride,
  }) {
    return makeTestableWidgetWithScaffold(
      const EvolutionSessionTimeline(templateId: kTestTemplateId),
      overrides: [
        evolutionSessionsProvider.overrideWith(
          sessionsOverride ?? (ref, id) async => [],
        ),
      ],
    );
  }

  group('EvolutionSessionTimeline', () {
    testWidgets('shows empty-state message when no sessions', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionNoSessions),
        findsOneWidget,
      );
    });

    testWidgets('shows CircularProgressIndicator while loading',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          sessionsOverride: (ref, id) =>
              Completer<List<AgentDomainEntity>>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders session number for active session', (tester) async {
      final sessions = <AgentDomainEntity>[
        // ignore: avoid_redundant_argument_values
        makeTestEvolutionSession(id: 'evo-1', sessionNumber: 1),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(1)),
        findsOneWidget,
      );
    });

    testWidgets('renders "Active" status badge for active session',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionStatusActive),
        findsOneWidget,
      );
    });

    testWidgets('renders "Completed" status badge for completed session',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionStatusCompleted),
        findsOneWidget,
      );
    });

    testWidgets('renders "Abandoned" status badge for abandoned session',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.abandoned,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionStatusAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('shows formatted creation date for session', (tester) async {
      final createdAt = DateTime(2024, 3, 15, 10, 30);
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
          createdAt: createdAt,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      // formatAgentDateTime uses 'yyyy-MM-dd HH:mm'
      expect(find.text('2024-03-15 10:30'), findsOneWidget);
    });

    testWidgets(
        'shows "Version proposed" for completed session with proposedVersionId',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
          proposedVersionId: 'version-42',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version proposed'), findsOneWidget);
    });

    testWidgets(
        'does not show "Version proposed" for completed session without '
        'proposedVersionId', (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version proposed'), findsNothing);
    });

    testWidgets(
        'does not show "Version proposed" for active session even with '
        'proposedVersionId', (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
          proposedVersionId: 'version-99',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version proposed'), findsNothing);
    });

    testWidgets('shows feedbackSummary text when present', (tester) async {
      const summary = 'Agent performed well on task resolution.';
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
          feedbackSummary: summary,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text(summary), findsOneWidget);
    });

    testWidgets('does not show feedback text when feedbackSummary is null',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      // No feedback summary italic text
      final italicFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontStyle == FontStyle.italic,
      );
      expect(italicFinder, findsNothing);
    });

    testWidgets('renders multiple sessions in order', (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          sessionNumber: 1,
          status: EvolutionSessionStatus.completed,
          createdAt: DateTime(2024, 3, 15, 10, 30),
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          status: EvolutionSessionStatus.abandoned,
          createdAt: DateTime(2024, 3, 20, 9),
        ),
        makeTestEvolutionSession(
          id: 'evo-3',
          sessionNumber: 3,
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
          createdAt: DateTime(2024, 3, 25, 14, 15),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(1)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(2)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(3)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionStatusCompleted),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionStatusAbandoned),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionStatusActive),
        findsOneWidget,
      );
    });

    testWidgets('renders timeline rail dots (circles) per session',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          sessionNumber: 1,
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      // Each session node has a circle decoration for the dot
      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circles, findsNWidgets(2));
    });

    testWidgets('renders connector line between non-last sessions',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          // ignore: avoid_redundant_argument_values
          sessionNumber: 1,
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
        ),
      ];

      await tester.pumpWidget(
        buildSubject(sessionsOverride: (ref, id) async => sessions),
      );
      await tester.pumpAndSettle();

      // The connector line is a 2px wide Container; last node has none.
      // With 2 sessions, there should be exactly 1 connector line.
      final connectors = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.minWidth == 2 &&
            w.constraints?.maxWidth == 2,
      );
      expect(connectors, findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink on provider error', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          sessionsOverride: (ref, id) =>
              Future<List<AgentDomainEntity>>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      // Error case renders SizedBox.shrink — no sessions, no spinner, no badge
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final context = tester.element(find.byType(EvolutionSessionTimeline));
      expect(
        find.text(context.messages.agentEvolutionNoSessions),
        findsNothing,
      );
    });
  });
}
