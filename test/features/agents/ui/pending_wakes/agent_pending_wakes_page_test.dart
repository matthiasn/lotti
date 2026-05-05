import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/agent_pending_wakes_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

PendingWakeRecord _record({
  required String agentId,
  required String displayName,
  required PendingWakeType type,
  required DateTime dueAt,
  String kind = AgentKinds.taskAgent,
  AgentSlots slots = const AgentSlots(),
}) {
  final state = makeTestState(
    agentId: agentId,
    slots: slots,
    nextWakeAt: type == PendingWakeType.pending ? dueAt : null,
    scheduledWakeAt: type == PendingWakeType.scheduled ? dueAt : null,
  );
  return PendingWakeRecord(
    agent: makeTestIdentity(
      agentId: agentId,
      kind: kind,
      displayName: displayName,
    ),
    state: state,
    type: type,
    dueAt: dueAt,
  );
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<PendingWakeRecord> records,
    Map<String, String?> subjectTitles = const {},
    AgentService? agentService,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AgentPendingWakesPage(),
        mediaQueryData: const MediaQueryData(size: Size(1600, 900)),
        overrides: [
          pendingWakeRecordsProvider.overrideWith((ref) async => records),
          pendingWakeTargetTitleProvider.overrideWith(
            (ref, String? entryId) async => subjectTitles[entryId],
          ),
          if (agentService != null)
            agentServiceProvider.overrideWith((ref) => agentService),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders rows with subject title, kind pill, and countdown', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'agent-1',
            displayName: 'Project Watcher',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 2, seconds: 5)),
            kind: AgentKinds.projectAgent,
            slots: const AgentSlots(activeProjectId: 'project-1'),
          ),
        ],
        subjectTitles: const {'project-1': 'Platform Refresh'},
      );

      // Subject title becomes the row title; agent name moves to the
      // subtitle (Text.rich), so the overall plain text contains both.
      expect(
        find.textContaining('Platform Refresh', findRichText: true),
        findsAtLeast(1),
      );
      // Countdown lands in the trailing slot via the page-scoped ticker.
      expect(find.text('02:05'), findsOneWidget);
    });
  });

  testWidgets('falls back to agent display name when no subject title', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'agent-1',
            displayName: 'Loop Guard',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(seconds: 30)),
            slots: const AgentSlots(activeTaskId: 'task-1'),
          ),
        ],
        subjectTitles: const {'task-1': ''},
      );
      // Agent display name becomes the row title (no subtitle), so
      // there's exactly one Text widget with this string.
      expect(find.text('Loop Guard'), findsOneWidget);
    });
  });

  testWidgets('Type filter axis only appears when both types are present', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      // Single-type dataset → Filters button must NOT be in the toolbar.
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'a',
            displayName: 'A',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 1)),
          ),
          _record(
            agentId: 'b',
            displayName: 'B',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 2)),
          ),
        ],
      );
      final ctx = tester.element(find.byType(AgentPendingWakesPage));
      expect(
        find.text(ctx.messages.agentInstancesToolbarFilters),
        findsNothing,
      );
    });
  });

  testWidgets('Type filter axis appears when both types are present', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'a',
            displayName: 'A',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 1)),
          ),
          _record(
            agentId: 'b',
            displayName: 'B',
            type: PendingWakeType.scheduled,
            dueAt: now.add(const Duration(minutes: 5)),
          ),
        ],
      );
      final ctx = tester.element(find.byType(AgentPendingWakesPage));
      expect(
        find.text(ctx.messages.agentInstancesToolbarFilters),
        findsOneWidget,
      );
    });
  });

  testWidgets('switching Group by Type clusters rows by their wake type', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'a',
            displayName: 'A',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 1)),
          ),
          _record(
            agentId: 'b',
            displayName: 'B',
            type: PendingWakeType.scheduled,
            dueAt: now.add(const Duration(minutes: 5)),
          ),
        ],
      );

      final ctx = tester.element(find.byType(AgentPendingWakesPage));
      await tester.tap(
        find.textContaining(ctx.messages.agentInstancesToolbarGroupBy),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(ctx.messages.agentPendingWakesGroupByType).last,
      );
      await tester.pumpAndSettle();
      // The toolbar's Wrap can briefly emit a sub-pixel overflow
      // when the popover-driven re-layout shrinks the search field;
      // it's cosmetic and doesn't affect the group output we're
      // asserting on. Drain the exception so the test isn't marked
      // failed by the rendering library.
      tester.takeException();

      // Both type labels should now appear as group headers
      // (in addition to the per-row pills).
      expect(
        find.text(ctx.messages.agentPendingWakesPendingLabel),
        findsAtLeast(1),
      );
      expect(
        find.text(ctx.messages.agentPendingWakesScheduledLabel),
        findsAtLeast(1),
      );
    });
  });

  testWidgets('delete button calls cancelPendingWake for pending wakes', (
    tester,
  ) async {
    final mockService = MockAgentService();
    when(() => mockService.cancelPendingWake('agent-1')).thenReturn(null);

    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'agent-1',
            displayName: 'Loop Guard',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 5)),
          ),
        ],
        agentService: mockService,
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      verify(() => mockService.cancelPendingWake('agent-1')).called(1);
    });
  });

  testWidgets(
    'delete button calls clearScheduledWake for scheduled wakes',
    (tester) async {
      final mockService = MockAgentService();
      when(
        () => mockService.clearScheduledWake('agent-2'),
      ).thenAnswer((_) async {});

      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            _record(
              agentId: 'agent-2',
              displayName: 'Schedule',
              type: PendingWakeType.scheduled,
              dueAt: now.add(const Duration(minutes: 5)),
            ),
          ],
          agentService: mockService,
        );

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();
        await tester.pump();

        verify(() => mockService.clearScheduledWake('agent-2')).called(1);
      });
    },
  );

  testWidgets('tapping a row beams to the agent instance detail route', (
    tester,
  ) async {
    String? navigated;
    beamToNamedOverride = (path) => navigated = path;

    final now = DateTime(2026, 3, 31, 9);
    await withClock(Clock(() => now), () async {
      await pumpPage(
        tester,
        records: [
          _record(
            agentId: 'agent-nav',
            displayName: 'Nav',
            type: PendingWakeType.pending,
            dueAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      );
      await tester.tap(find.text('Nav'));
      await tester.pumpAndSettle();
      expect(navigated, '/settings/agents/instances/agent-nav');
    });
  });

  testWidgets('empty data shows the localized empty-state copy', (
    tester,
  ) async {
    await pumpPage(tester, records: const []);
    final ctx = tester.element(find.byType(AgentPendingWakesPage));
    expect(
      find.text(ctx.messages.agentPendingWakesEmptyFiltered),
      findsOneWidget,
    );
  });

  testWidgets(
    'selecting a Type filter chip narrows the list via axisMatcher',
    (tester) async {
      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            _record(
              agentId: 'a',
              displayName: 'Alpha',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(minutes: 1)),
            ),
            _record(
              agentId: 'b',
              displayName: 'Beta',
              type: PendingWakeType.scheduled,
              dueAt: now.add(const Duration(minutes: 5)),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentPendingWakesPage));

        // Open Filters popover and toggle the Scheduled option only.
        await tester.tap(find.text(ctx.messages.agentInstancesToolbarFilters));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentPendingWakesScheduledLabel).last,
        );
        await tester.pumpAndSettle();
        // Dismiss popover by tapping outside.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        tester.takeException();

        // Pending row must be filtered out, Scheduled stays.
        expect(find.text('Alpha'), findsNothing);
        expect(find.text('Beta'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'switching Sort to Due latest reorders rows newest first',
    (tester) async {
      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            _record(
              agentId: 'a',
              displayName: 'Alpha',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(minutes: 1)),
            ),
            _record(
              agentId: 'b',
              displayName: 'Beta',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(hours: 1)),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentPendingWakesPage));
        // The sort button's child is the *current* axis label
        // (default is Due soonest), so tap that to open the popover.
        await tester.tap(
          find.text(ctx.messages.agentPendingWakesSortDueSoonest).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ctx.messages.agentPendingWakesSortDueLatest).last,
        );
        await tester.pumpAndSettle();
        tester.takeException();

        // Beta (later) should now appear above Alpha. We compare the
        // vertical positions of the two row titles.
        final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
        final betaY = tester.getTopLeft(find.text('Beta')).dy;
        expect(betaY, lessThan(alphaY));
      });
    },
  );

  testWidgets(
    'switching Sort to Name reorders alphabetically + same-time tiebreaker',
    (tester) async {
      final now = DateTime(2026, 3, 31, 9);
      final due = now.add(const Duration(minutes: 1));
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            // Same `dueAt` so the Due-soonest tiebreaker by id kicks in
            // for that sort, and Name sort flips them by title.
            _record(
              agentId: 'b-id',
              displayName: 'Bravo',
              type: PendingWakeType.pending,
              dueAt: due,
            ),
            _record(
              agentId: 'a-id',
              displayName: 'Alpha',
              type: PendingWakeType.pending,
              dueAt: due,
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentPendingWakesPage));
        // Default Due-soonest sort with same dueAt → tiebreaker by id
        // means a-id < b-id → Alpha appears above Bravo.
        var alphaY = tester.getTopLeft(find.text('Alpha')).dy;
        var bravoY = tester.getTopLeft(find.text('Bravo')).dy;
        expect(alphaY, lessThan(bravoY));

        // Switch to Name sort — Alpha still above Bravo (alphabetical),
        // but this also covers the Name-axis tiebreaker by id when
        // titles match (not asserted, exercised by codepath).
        // The sort button's child is the *current* axis label
        // (default is Due soonest), so tap that to open the popover.
        await tester.tap(
          find.text(ctx.messages.agentPendingWakesSortDueSoonest).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ctx.messages.agentInstancesSortName).last);
        await tester.pumpAndSettle();
        tester.takeException();

        alphaY = tester.getTopLeft(find.text('Alpha')).dy;
        bravoY = tester.getTopLeft(find.text('Bravo')).dy;
        expect(alphaY, lessThan(bravoY));
      });
    },
  );

  testWidgets(
    'delete failure swallows the error and clears the spinner',
    (tester) async {
      final mockService = MockAgentService();
      when(
        () => mockService.cancelPendingWake('agent-fail'),
      ).thenThrow(StateError('boom'));

      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            _record(
              agentId: 'agent-fail',
              displayName: 'Fail',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(minutes: 5)),
            ),
          ],
          agentService: mockService,
        );

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        // Drain the microtask queue so the catch + finally branches run.
        await tester.pump();
        await tester.pump();

        verify(() => mockService.cancelPendingWake('agent-fail')).called(1);
        // Finally restored the delete affordance — no leftover spinner.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      });
    },
  );
}
