import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

const String _testAgentId = kTestAgentId;

void main() {
  late MockAgentService mockAgentService;
  late MockTaskAgentService mockTaskAgentService;

  setUp(() {
    mockAgentService = MockAgentService();
    mockTaskAgentService = MockTaskAgentService();
  });

  /// Builds [AgentDetailPage] with provider overrides.
  Widget buildSubject({
    FutureOr<AgentDomainEntity?> Function(Ref, String)? identityOverride,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? stateOverride,
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)? messagesOverride,
    FutureOr<Map<String, List<AgentDomainEntity>>> Function(Ref, String)?
        threadOverride,
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)?
        observationsOverride,
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)?
        reportHistoryOverride,
    Stream<bool> Function(Ref, String)? isRunningOverride,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? templateOverride,
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentDetailPage(agentId: _testAgentId),
      overrides: [
        agentIdentityProvider.overrideWith(
          identityOverride ?? (ref, agentId) async => null,
        ),
        agentStateProvider.overrideWith(
          stateOverride ?? (ref, agentId) async => null,
        ),
        agentReportProvider.overrideWith(
          (ref, agentId) async => null,
        ),
        agentRecentMessagesProvider.overrideWith(
          messagesOverride ?? (ref, agentId) async => <AgentDomainEntity>[],
        ),
        agentMessagesByThreadProvider.overrideWith(
          threadOverride ??
              (ref, agentId) async => <String, List<AgentDomainEntity>>{},
        ),
        agentObservationMessagesProvider.overrideWith(
          observationsOverride ?? (ref, agentId) async => <AgentDomainEntity>[],
        ),
        agentReportHistoryProvider.overrideWith(
          reportHistoryOverride ??
              (ref, agentId) async => <AgentDomainEntity>[],
        ),
        agentIsRunningProvider.overrideWith(
          isRunningOverride ?? (ref, agentId) => Stream.value(false),
        ),
        templateForAgentProvider.overrideWith(
          templateOverride ?? (ref, agentId) async => null,
        ),
        agentServiceProvider.overrideWithValue(mockAgentService),
        taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
        ...extraOverrides,
      ],
    );
  }

  /// Helper that builds the subject with simple data overrides.
  Widget buildDataSubject({
    AgentDomainEntity? identity,
    AgentDomainEntity? state,
    List<AgentDomainEntity> messages = const [],
  }) {
    return buildSubject(
      identityOverride: (ref, agentId) async => identity,
      stateOverride: (ref, agentId) async => state,
      messagesOverride: (ref, agentId) async => messages,
    );
  }

  group('AgentDetailPage', () {
    testWidgets('shows loading indicator while identity loads', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          identityOverride: (ref, agentId) =>
              Completer<AgentDomainEntity?>().future,
          stateOverride: (ref, agentId) =>
              Completer<AgentDomainEntity?>().future,
          messagesOverride: (ref, agentId) =>
              Completer<List<AgentDomainEntity>>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows agent name in app bar', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(identity: makeTestIdentity()),
      );
      await tester.pump();

      expect(find.text('Test Agent'), findsOneWidget);
    });

    testWidgets('shows lifecycle badge as Active', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(identity: makeTestIdentity()),
      );
      await tester.pump();

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows lifecycle badge as Paused for dormant agent',
        (tester) async {
      await tester.pumpWidget(
        buildDataSubject(
          identity: makeTestIdentity(lifecycle: AgentLifecycle.dormant),
        ),
      );
      await tester.pump();

      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('shows lifecycle badge as Destroyed', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(
          identity: makeTestIdentity(lifecycle: AgentLifecycle.destroyed),
        ),
      );
      await tester.pump();

      expect(find.text('Destroyed'), findsOneWidget);
    });

    testWidgets('shows lifecycle badge as Created', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(
          identity: makeTestIdentity(lifecycle: AgentLifecycle.created),
        ),
      );
      await tester.pump();

      expect(find.text('Created'), findsOneWidget);
    });

    testWidgets('shows "Agent not found" when identity is null',
        (tester) async {
      await tester.pumpWidget(buildDataSubject());
      await tester.pump();

      expect(find.text('Agent not found.'), findsOneWidget);
    });

    testWidgets('shows error message when identity fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          identityOverride: (ref, agentId) =>
              Future<AgentDomainEntity?>.error(Exception('Network error')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Error loading agent'),
        findsOneWidget,
      );
    });

    testWidgets('shows Activity, Reports, Conversations, and Observations tabs',
        (tester) async {
      await tester.pumpWidget(
        buildDataSubject(identity: makeTestIdentity()),
      );
      await tester.pump();

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
    });

    testWidgets('shows state info section with values', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(
          identity: makeTestIdentity(),
          state: makeTestState(
            revision: 5,
            wakeCounter: 12,
            consecutiveFailureCount: 2,
            lastWakeAt: DateTime(2024, 3, 15, 9, 30),
            nextWakeAt: DateTime(2024, 3, 15, 14),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('State Info'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // Revision value
      expect(find.text('12'), findsOneWidget); // Wake count value
      expect(find.text('2'), findsOneWidget); // Consecutive failures
      expect(find.text('2024-03-15 09:30'), findsOneWidget); // Last wake
      expect(find.text('2024-03-15 14:00'), findsOneWidget); // Next wake
    });

    testWidgets(
      'shows sleepUntil in state info when present',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestState(
              sleepUntil: DateTime(2024, 3, 16, 8),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('2024-03-16 08:00'), findsOneWidget);
      },
    );

    testWidgets(
      'hides optional date fields when null',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestState(),
          ),
        );
        await tester.pump();

        expect(find.text('Last wake'), findsNothing);
        expect(find.text('Next wake'), findsNothing);
        expect(find.text('Sleeping until'), findsNothing);
      },
    );

    testWidgets('shows "Unexpected entity type" for non-agent identity',
        (tester) async {
      // Return an agentState (non-agent) entity as identity.
      await tester.pumpWidget(
        buildDataSubject(identity: makeTestState()),
      );
      await tester.pump();

      expect(find.text('Unexpected entity type.'), findsOneWidget);
    });

    testWidgets('shows state error message when state fails', (tester) async {
      final stateError = Exception('State DB error');
      await tester.pumpWidget(
        buildSubject(
          identityOverride: (ref, agentId) async => makeTestIdentity(),
          extraOverrides: [
            agentStateProvider(_testAgentId).overrideWithValue(
              AsyncValue<AgentDomainEntity?>.error(
                stateError,
                StackTrace.current,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Failed to load state'),
        findsOneWidget,
      );
    });

    testWidgets('shows agent controls section', (tester) async {
      await tester.pumpWidget(
        buildDataSubject(identity: makeTestIdentity()),
      );
      await tester.pump();

      // Active lifecycle should show Pause, Re-analyze, and Destroy
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Re-analyze'), findsOneWidget);
      expect(find.text('Destroy'), findsOneWidget);
    });

    testWidgets(
      'shows state with only lastWakeAt, hides nextWakeAt and sleepUntil',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestState(
              lastWakeAt: DateTime(2024, 3, 15, 9, 30),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Last wake'), findsOneWidget);
        expect(find.text('2024-03-15 09:30'), findsOneWidget);
        expect(find.textContaining('Next wake'), findsNothing);
        expect(find.textContaining('Sleeping until'), findsNothing);
      },
    );

    testWidgets(
      'shows state with only nextWakeAt, hides lastWakeAt and sleepUntil',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestState(
              nextWakeAt: DateTime(2024, 3, 15, 14),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Next wake'), findsOneWidget);
        expect(find.text('2024-03-15 14:00'), findsOneWidget);
        expect(find.textContaining('Last wake'), findsNothing);
        expect(find.textContaining('Sleeping until'), findsNothing);
      },
    );

    testWidgets(
      'state info shows labels alongside values',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestState(
              revision: 7,
              wakeCounter: 3,
              consecutiveFailureCount: 1,
            ),
          ),
        );
        await tester.pump();

        // Verify labels are present
        expect(find.textContaining('Revision'), findsOneWidget);
        expect(find.textContaining('Wake count'), findsOneWidget);
        expect(find.textContaining('Consecutive failures'), findsOneWidget);

        // Verify values are present
        expect(find.text('7'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'hides state info section when state is null',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(identity: makeTestIdentity()),
        );
        await tester.pump();

        // No state section heading when state is null
        expect(find.text('State Info'), findsNothing);
      },
    );

    testWidgets(
      'non-agentState entity as state shows empty',
      (tester) async {
        // Return an agentReport entity as the state — mapOrNull returns null
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(),
            state: makeTestReport(),
          ),
        );
        await tester.pump();

        // No state info section rendered
        expect(find.text('State Info'), findsNothing);
      },
    );

    testWidgets('shows running spinner when agent is running', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          identityOverride: (ref, agentId) async => makeTestIdentity(),
          isRunningOverride: (ref, agentId) => Stream.value(true),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The running spinner should appear in the app bar.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The tooltip with the running indicator label should be present.
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('hides running spinner when agent is not running',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          identityOverride: (ref, agentId) async => makeTestIdentity(),
          isRunningOverride: (ref, agentId) => Stream.value(false),
        ),
      );
      await tester.pump();
      await tester.pump();

      // No spinner in the app bar.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // No tooltip for running indicator.
      expect(find.byTooltip('Running'), findsNothing);
    });

    testWidgets(
      'shows dormant controls for dormant agent',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(lifecycle: AgentLifecycle.dormant),
          ),
        );
        await tester.pump();

        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Pause'), findsNothing);
      },
    );

    testWidgets(
      'shows destroyed controls for destroyed agent',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(
            identity: makeTestIdentity(lifecycle: AgentLifecycle.destroyed),
          ),
        );
        await tester.pump();

        expect(
          find.text('This agent has been destroyed.'),
          findsOneWidget,
        );
        expect(find.text('Delete permanently'), findsOneWidget);
        expect(find.text('Pause'), findsNothing);
        expect(find.text('Resume'), findsNothing);
      },
    );

    testWidgets(
      'shows template section with template name when assigned',
      (tester) async {
        final template = makeTestTemplate(displayName: 'Laura');

        await tester.pumpWidget(
          buildSubject(
            identityOverride: (ref, agentId) async => makeTestIdentity(),
            templateOverride: (ref, agentId) async => template,
          ),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(AgentDetailPage));
        expect(
          find.text(context.messages.agentTemplateAssignedLabel),
          findsOneWidget,
        );
        expect(find.text('Laura'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "No template assigned" when no template',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(identity: makeTestIdentity()),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(AgentDetailPage));
        expect(
          find.text(context.messages.agentTemplateNoneAssigned),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows template switch hint',
      (tester) async {
        await tester.pumpWidget(
          buildDataSubject(identity: makeTestIdentity()),
        );
        await tester.pump();

        final context = tester.element(find.byType(AgentDetailPage));
        expect(
          find.text(context.messages.agentTemplateSwitchHint),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows loading indicator while template loads',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            identityOverride: (ref, agentId) async => makeTestIdentity(),
            templateOverride: (ref, agentId) =>
                Completer<AgentDomainEntity?>().future,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Loading spinner inside the template section
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'shows error text when template loading fails',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            identityOverride: (ref, agentId) async => makeTestIdentity(),
            templateOverride: (ref, agentId) =>
                Future<AgentDomainEntity?>.error(Exception('template error')),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AgentDetailPage));
        expect(
          find.text(context.messages.commonError),
          findsOneWidget,
        );
      },
    );
  });
}
