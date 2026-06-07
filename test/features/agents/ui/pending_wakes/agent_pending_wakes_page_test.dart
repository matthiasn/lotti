import 'dart:async';

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
import 'package:lotti/l10n/app_localizations.dart';
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
    List<OngoingWakeRecord> ongoing = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const AgentPendingWakesPage(),
        mediaQueryData: const MediaQueryData(size: Size(1600, 900)),
        overrides: [
          pendingWakeRecordsProvider.overrideWith((ref) async => records),
          ongoingWakeRecordsProvider.overrideWith((ref) async => ongoing),
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

  testWidgets('renders the localized kind pill for every AgentKinds value', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 31, 9);
    // (kind constant, localized-label resolver) for each known kind. The
    // page renders one pill per row using `pendingWakeKindLabel`, so the
    // localized label must appear once per kind, distinct from one another.
    final kindLabelOf = <String, String Function(AppLocalizations)>{
      AgentKinds.taskAgent: (m) => m.agentInstancesKindTaskAgent,
      AgentKinds.dayAgent: (m) => m.agentTemplateKindDayAgent,
      AgentKinds.projectAgent: (m) => m.agentTemplateKindProjectAgent,
      AgentKinds.templateImprover: (m) => m.agentTemplateKindImprover,
    };

    await withClock(Clock(() => now), () async {
      // One row per kind. Distinct display names keep the row titles unique
      // so a kind label can never be confused with a fallback title.
      final kinds = kindLabelOf.keys.toList();
      await pumpPage(
        tester,
        records: [
          for (final (index, kind) in kinds.indexed)
            _record(
              agentId: 'agent-$index',
              displayName: 'Agent $index',
              type: PendingWakeType.pending,
              dueAt: now.add(Duration(minutes: index + 1)),
              kind: kind,
            ),
        ],
      );

      final messages = tester
          .element(find.byType(AgentPendingWakesPage))
          .messages;
      // Every kind's localized label must render exactly once (one pill per
      // row), and the four labels must all be distinct strings so the test
      // genuinely distinguishes the kinds.
      final renderedLabels = <String>{};
      for (final kind in kinds) {
        final label = kindLabelOf[kind]!(messages);
        renderedLabels.add(label);
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'kind pill missing for $kind ($label)',
        );
      }
      expect(renderedLabels, hasLength(kinds.length));
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
      // The toolbar can briefly emit a transient sub-pixel RenderFlex
      // overflow while the popover-driven re-layout shrinks the search
      // field; the settled frame is clean (verified: the other former
      // drains in this file never fired). Drain the cosmetic mid-animation
      // exception, but assert it is *only* that known overflow so a real,
      // unrelated exception can never be silently swallowed here.
      final swallowed = tester.takeException();
      if (swallowed != null) {
        expect(
          swallowed.toString(),
          contains('overflowed'),
          reason: 'unexpected exception swallowed after group-by popover',
        );
      }

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

  testWidgets(
    'shows an in-flight spinner while a scheduled delete is pending',
    (tester) async {
      // Hold the clear() future open so `_isDeleting` stays true and the
      // CircularProgressIndicator branch (not the IconButton) renders.
      final gate = Completer<void>();
      final mockService = MockAgentService();
      when(
        () => mockService.clearScheduledWake('agent-busy'),
      ).thenAnswer((_) => gate.future);

      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            _record(
              agentId: 'agent-busy',
              displayName: 'Busy',
              type: PendingWakeType.scheduled,
              dueAt: now.add(const Duration(minutes: 5)),
            ),
          ],
          agentService: mockService,
        );

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();

        // While the future is unresolved the delete icon is replaced by a
        // spinner.
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Resolving the future restores the delete affordance.
        gate.complete();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        verify(() => mockService.clearScheduledWake('agent-busy')).called(1);
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

        alphaY = tester.getTopLeft(find.text('Alpha')).dy;
        bravoY = tester.getTopLeft(find.text('Bravo')).dy;
        expect(alphaY, lessThan(bravoY));
      });
    },
  );

  testWidgets(
    'Name sort breaks ties by id when two rows share the same title',
    (tester) async {
      String? navigated;
      beamToNamedOverride = (path) => navigated = path;

      final now = DateTime(2026, 3, 31, 9);
      await withClock(Clock(() => now), () async {
        await pumpPage(
          tester,
          records: [
            // Identical display name so Name sort's `byName` is 0 and
            // ordering falls through to the id tiebreaker (a-id < b-id).
            // The dueAt values are deliberately the *inverse* of the id
            // order: b-id is due sooner than a-id. Under the default
            // Due-Soonest sort that puts b-id on top, so asserting a-id is
            // on top only holds once we've actually switched to Name sort —
            // distinguishing Name sort from the default.
            _record(
              agentId: 'b-id',
              displayName: 'Twin',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(minutes: 1)),
            ),
            _record(
              agentId: 'a-id',
              displayName: 'Twin',
              type: PendingWakeType.pending,
              dueAt: now.add(const Duration(minutes: 5)),
            ),
          ],
        );

        final ctx = tester.element(find.byType(AgentPendingWakesPage));
        // Default (Due Soonest) sort: b-id is due sooner, so it sits on top
        // and tapping the top "Twin" beams to b-id. Asserting this before
        // touching the sort control proves the default order genuinely
        // differs from Name sort, so the post-switch assertion below can't
        // pass without the switch actually reordering the rows.
        await tester.tap(find.text('Twin').first);
        await tester.pumpAndSettle();
        expect(navigated, '/settings/agents/instances/b-id');
        navigated = null;

        // Switch to Name sort: open the sort menu (button label) and pick
        // "Name" (the menu item — `.last`, since the button label also
        // matches). Identical titles tie, so the id tiebreaker (a-id < b-id)
        // wins and a-id rises to the top — flipping the order.
        await tester.tap(
          find.text(ctx.messages.agentPendingWakesSortDueSoonest).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ctx.messages.agentInstancesSortName).last);
        await tester.pumpAndSettle();

        // Both rows render identical "Twin" titles, so identify ordering by
        // tapping the topmost row and asserting it beams to a-id's route —
        // proving the id tiebreaker (not insertion order) placed a-id first.
        final titles = find.text('Twin');
        expect(titles, findsNWidgets(2));
        final topTitle = titles.first;
        final bottomTitle = titles.last;
        expect(
          tester.getTopLeft(topTitle).dy,
          lessThan(tester.getTopLeft(bottomTitle).dy),
        );

        await tester.tap(topTitle);
        await tester.pumpAndSettle();
        expect(navigated, '/settings/agents/instances/a-id');
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

  group('Running instances block', () {
    testWidgets('renders the heading + a row per running wake', (tester) async {
      final now = DateTime(2026, 5, 5, 21);
      final ongoing = [
        OngoingWakeRecord(
          agentId: 'agent-running-1',
          title: 'Improve Agent UI/UX',
          startedAt: now.subtract(const Duration(seconds: 35)),
        ),
        OngoingWakeRecord(
          agentId: 'agent-running-2',
          title: 'Sync inbox',
          startedAt: now.subtract(const Duration(minutes: 2, seconds: 8)),
        ),
      ];
      await withClock(Clock(() => now), () async {
        await pumpPage(tester, records: const [], ongoing: ongoing);
      });

      final element = tester.element(find.byType(AgentPendingWakesPage));
      expect(
        find.text(element.messages.agentPendingWakesRunningHeading(2)),
        findsOneWidget,
      );
      expect(find.text('Improve Agent UI/UX'), findsOneWidget);
      expect(find.text('Sync inbox'), findsOneWidget);
      // Elapsed pills render in MM:SS once below the hour.
      expect(find.text('00:35'), findsOneWidget);
      expect(find.text('02:08'), findsOneWidget);
    });

    testWidgets(
      'renders the elapsed pill in H:MM:SS once the run crosses one hour',
      (tester) async {
        final now = DateTime(2026, 5, 5, 21);
        final ongoing = [
          OngoingWakeRecord(
            agentId: 'agent-long',
            title: 'Long runner',
            // 1h 30m 07s ago → the elapsed pill must add the hour cell.
            startedAt: now.subtract(
              const Duration(hours: 1, minutes: 30, seconds: 7),
            ),
          ),
        ];
        await withClock(Clock(() => now), () async {
          await pumpPage(tester, records: const [], ongoing: ongoing);
        });

        // Below-hour MM:SS form must NOT appear for a >1h run; the hour cell
        // is present.
        expect(find.text('01:30:07'), findsOneWidget);
        expect(find.text('30:07'), findsNothing);
      },
    );

    testWidgets(
      'tapping a running instance row beams to its instance detail page',
      (tester) async {
        final now = DateTime(2026, 5, 5, 21);
        String? captured;
        beamToNamedOverride = (uri) => captured = uri;

        await withClock(Clock(() => now), () async {
          await pumpPage(
            tester,
            records: const [],
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-tap',
                title: 'In flight',
                startedAt: now,
              ),
            ],
          );
        });

        await tester.tap(find.text('In flight'));
        await tester.pump();

        expect(captured, '/settings/agents/instances/agent-tap');
      },
    );

    testWidgets('block is hidden when no wakes are running', (tester) async {
      final now = DateTime(2026, 5, 5, 21);
      await withClock(Clock(() => now), () async {
        await pumpPage(tester, records: const []);
      });

      final element = tester.element(find.byType(AgentPendingWakesPage));
      expect(
        find.text(element.messages.agentPendingWakesRunningHeading(0)),
        findsNothing,
      );
    });

    testWidgets(
      'block is suppressed (no crash, no toast) when the provider errors',
      (tester) async {
        // The page reads `ongoingAsync.value ?? const []`, so an errored
        // ongoing provider must degrade to no running block — the rest of
        // the page (the listing + its empty state) still renders, and no
        // error toast leaks to the user.
        final now = DateTime(2026, 5, 5, 21);
        await withClock(Clock(() => now), () async {
          await tester.binding.setSurfaceSize(const Size(1600, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const AgentPendingWakesPage(),
              mediaQueryData: const MediaQueryData(size: Size(1600, 900)),
              overrides: [
                pendingWakeRecordsProvider.overrideWith(
                  (ref) async => const <PendingWakeRecord>[],
                ),
                ongoingWakeRecordsProvider.overrideWith(
                  (ref) async => throw StateError('ongoing boom'),
                ),
                pendingWakeTargetTitleProvider.overrideWith(
                  (ref, String? entryId) async => null,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
        });

        final element = tester.element(find.byType(AgentPendingWakesPage));
        // No running block heading rendered for the errored provider.
        expect(
          find.text(element.messages.agentPendingWakesRunningHeading(1)),
          findsNothing,
        );
        // The listing still rendered its empty-state copy — the page did
        // not crash or get replaced by an error shell.
        expect(
          find.text(element.messages.agentPendingWakesEmptyFiltered),
          findsOneWidget,
        );
        // The error must not surface as a toast / unhandled exception.
        expect(find.text(element.messages.commonError), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
