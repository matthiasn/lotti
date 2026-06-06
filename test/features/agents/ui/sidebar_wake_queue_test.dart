import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  // Local clock used by `_remainingFromDueAt`. Pinned so tests don't drift.
  final fixedNow = DateTime(2026, 5, 4, 20, 30);

  PendingWakeRecord makeWake({
    required String agentId,
    required String displayName,
    required Duration eta,
    PendingWakeType type = PendingWakeType.pending,
  }) {
    return PendingWakeRecord(
      agent: makeTestIdentity(
        agentId: agentId,
        id: agentId,
        displayName: displayName,
      ),
      state: makeTestState(agentId: agentId),
      type: type,
      dueAt: fixedNow.add(eta),
    );
  }

  Widget buildSubject(
    List<PendingWakeRecord> records, {
    MockAgentService? agentService,
    List<OngoingWakeRecord> ongoing = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      const SidebarWakeQueue(),
      theme: DesignSystemTheme.dark(),
      overrides: [
        pendingWakeRecordsProvider.overrideWith((ref) async => records),
        ongoingWakeRecordsProvider.overrideWith((ref) async => ongoing),
        if (agentService != null)
          agentServiceProvider.overrideWith((ref) => agentService),
      ],
    );
  }

  setUp(() {
    SidebarWakeQueueTestHooks.navigatorOverride = null;
  });

  tearDown(() {
    SidebarWakeQueueTestHooks.navigatorOverride = null;
  });

  testWidgets(
    'renders nothing while wakes are still loading — the queue stays '
    'hidden until there is actionable work, so enabling the section does '
    'not add a chrome-only card above Settings',
    (tester) async {
      final completer = Completer<List<PendingWakeRecord>>();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SidebarWakeQueue(),
          theme: DesignSystemTheme.dark(),
          overrides: [
            pendingWakeRecordsProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );

      final element = tester.element(find.byType(SidebarWakeQueue));
      expect(
        find.text(element.messages.sidebarWakesHeader.toUpperCase()),
        findsNothing,
      );
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);

      completer.complete(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'renders nothing when no wakes are pending — the empty-zero header was '
    'noise above Settings, so the card is hidden until at least one wake '
    'is queued',
    (tester) async {
      await tester.pumpWidget(buildSubject(const []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final element = tester.element(find.byType(SidebarWakeQueue));
      expect(
        find.text(element.messages.sidebarWakesHeader.toUpperCase()),
        findsNothing,
      );
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    },
  );

  testWidgets('renders header count, in-window rows, and +N more link', (
    tester,
  ) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        buildSubject([
          makeWake(
            agentId: 'a-1',
            displayName: 'Laura',
            eta: const Duration(seconds: 28),
          ),
          makeWake(
            agentId: 'a-2',
            displayName: 'Iris',
            eta: const Duration(seconds: 50),
          ),
          makeWake(
            agentId: 'a-3',
            displayName: 'Kit',
            eta: const Duration(hours: 9, minutes: 24),
            type: PendingWakeType.scheduled,
          ),
          makeWake(
            agentId: 'a-4',
            displayName: 'Max',
            eta: const Duration(hours: 9, minutes: 24),
          ),
          makeWake(
            agentId: 'a-5',
            displayName: 'Tom',
            eta: const Duration(hours: 9, minutes: 24),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    final element = tester.element(find.byType(SidebarWakeQueue));
    final messages = element.messages;

    // Header label + count. The widget upper-cases the label so it reads
    // as a small-caps mono treatment regardless of the translator's
    // capitalization choices.
    expect(
      find.text(messages.sidebarWakesHeader.toUpperCase()),
      findsOneWidget,
    );
    // Only wakes within the 1h lookahead window count toward the
    // header badge — Kit / Max / Tom (9h+ out) are intentionally
    // invisible from the sidebar entirely, so the badge reads the
    // imminent count (2), not the queue total (5).
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Laura'), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(find.text('Kit'), findsNothing);

    // Imminent ETA renders as mm:ss.
    expect(find.text('00:28'), findsOneWidget);
    expect(find.text('00:50'), findsOneWidget);

    // The header link icon is the only path into the full Wake Cycles
    // page — there is no per-row trailing "+N more" link any more.
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });

  testWidgets('shows "now" when the next wake is due', (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        buildSubject([
          makeWake(
            agentId: 'a-1',
            displayName: 'Laura',
            eta: Duration.zero,
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    final element = tester.element(find.byType(SidebarWakeQueue));
    expect(find.text(element.messages.sidebarWakesNow), findsOneWidget);
  });

  // The previous "ETAs over an hour render as Xh MMm" test no longer
  // applies — the sidebar now filters scheduled wakes to a 1-hour
  // lookahead window, so multi-hour ETAs collapse into the trailing
  // "+N more →" link rather than rendering inline. The mm:ss formatter
  // for the in-window range is exercised by the "renders header count"
  // test above.

  testWidgets('tapping a row navigates to the agent instance route', (
    tester,
  ) async {
    String? captured;
    SidebarWakeQueueTestHooks.navigatorOverride = (path) => captured = path;

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        buildSubject([
          makeWake(
            agentId: 'agent-xyz',
            displayName: 'Laura',
            eta: const Duration(seconds: 30),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    await tester.tap(find.text('Laura'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(captured, '/settings/agents/instances/agent-xyz');
  });

  testWidgets(
    'tapping the header link icon navigates to the Wake Cycles page',
    (tester) async {
      String? captured;
      SidebarWakeQueueTestHooks.navigatorOverride = (path) => captured = path;

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'a-1',
              displayName: 'Laura',
              eta: const Duration(seconds: 28),
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      await tester.tap(find.byIcon(Icons.open_in_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(captured, kSidebarWakeQueueListRoute);
    },
  );

  testWidgets(
    'tapping the trailing × on a pending wake calls cancelPendingWake on '
    'the agent service',
    (tester) async {
      final agentService = MockAgentService();
      when(() => agentService.cancelPendingWake(any())).thenReturn(null);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            [
              makeWake(
                agentId: 'agent-pending',
                displayName: 'Laura',
                eta: const Duration(seconds: 30),
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => agentService.cancelPendingWake('agent-pending')).called(1);
      verifyNever(() => agentService.clearScheduledWake(any()));
    },
  );

  testWidgets(
    'scheduled wake row falls through to the project title when the task '
    'title is empty — covers the case where slots.activeTaskId points at '
    'an entry with a blank/whitespace title and the row collapsed to the '
    'agent.displayName (Task Agent or similar) instead of the project',
    (tester) async {
      final identity = makeTestIdentity(
        agentId: 'agent-fallthrough',
        id: 'agent-fallthrough',
        displayName: 'Task Agent',
      );
      final state = makeTestState(
        agentId: 'agent-fallthrough',
        slots: const AgentSlots(
          activeTaskId: 'task-empty',
          activeProjectId: 'project-named',
        ),
      );
      final record = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.pending,
        dueAt: fixedNow.add(const Duration(seconds: 30)),
      );

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SidebarWakeQueue(),
            theme: DesignSystemTheme.dark(),
            overrides: [
              pendingWakeRecordsProvider.overrideWith((ref) async => [record]),
              ongoingWakeRecordsProvider.overrideWith(
                (ref) async => const <OngoingWakeRecord>[],
              ),
              // Task title resolves to whitespace — would have collapsed
              // straight to the displayName before the fix.
              pendingWakeTargetTitleProvider(
                'task-empty',
              ).overrideWith((ref) async => null),
              pendingWakeTargetTitleProvider(
                'project-named',
              ).overrideWith((ref) async => 'Platform refresh'),
            ],
          ),
        );
        // Two pumps: one for the initial build, one for the title
        // futures to settle and the row to rebuild with the resolved
        // project title.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(find.text('Platform refresh'), findsOneWidget);
      expect(find.text('Task Agent'), findsNothing);
    },
  );

  testWidgets(
    'scheduled wake row reacts live to a rename of its linked task '
    'instead of caching the snapshot title until the wake fires',
    (tester) async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final identity = makeTestIdentity(
        agentId: 'agent-rename',
        id: 'agent-rename',
        displayName: 'Task Agent',
      );
      final state = makeTestState(
        agentId: 'agent-rename',
        slots: const AgentSlots(activeTaskId: 'task-rename'),
      );
      final record = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.pending,
        dueAt: fixedNow.add(const Duration(seconds: 30)),
      );

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SidebarWakeQueue(),
            theme: DesignSystemTheme.dark(),
            overrides: [
              pendingWakeRecordsProvider.overrideWith((ref) async => [record]),
              ongoingWakeRecordsProvider.overrideWith(
                (ref) async => const <OngoingWakeRecord>[],
              ),
              pendingWakeTargetTitleProvider(
                'task-rename',
              ).overrideWith((ref) => controller.stream.first),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        controller.add('GLaDOS');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('GLaDOS'), findsOneWidget);
        expect(find.text('Task Agent'), findsNothing);
      });
    },
  );

  testWidgets(
    'tapping the trailing × on a scheduled wake calls clearScheduledWake on '
    'the agent service',
    (tester) async {
      final agentService = MockAgentService();
      when(
        () => agentService.clearScheduledWake(any()),
      ).thenAnswer((_) async {});

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            [
              // Within the 1h lookahead so the row renders inline and
              // the cancel × is reachable. Out-of-window wakes are
              // collapsed under "+N more" and have no per-row affordance.
              makeWake(
                agentId: 'agent-scheduled',
                displayName: 'Kit',
                eta: const Duration(minutes: 30),
                type: PendingWakeType.scheduled,
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => agentService.clearScheduledWake('agent-scheduled'),
      ).called(1);
      verifyNever(() => agentService.cancelPendingWake(any()));
    },
  );

  testWidgets(
    'tapping a row with no test override beams the Settings delegate to the '
    'agent instance route via the real NavService — covers the production '
    'path of `_navigateToAgentRoute` when `navigatorOverride` is null',
    (tester) async {
      SidebarWakeQueueTestHooks.navigatorOverride = null;

      final mockNav = MockNavService();
      final mockDelegate = _RecordingBeamerDelegate();
      when(() => mockNav.index).thenReturn(0); // not on Settings
      when(() => mockNav.settingsIndex).thenReturn(6);
      when(() => mockNav.setIndex(any())).thenReturn(null);
      when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
      when(
        () => mockNav.persistNamedRoute(any()),
      ).thenAnswer((_) async {});

      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(mockNav);
      addTearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'agent-prod',
              displayName: 'Laura',
              eta: const Duration(seconds: 30),
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      await tester.tap(find.text('Laura'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mockNav.setIndex(6)).called(1);
      verify(
        () =>
            mockNav.persistNamedRoute('/settings/agents/instances/agent-prod'),
      ).called(1);
      expect(mockDelegate.beamed, ['/settings/agents/instances/agent-prod']);
    },
  );

  testWidgets(
    'tapping a row when already on the Settings tab skips the setIndex '
    'call so in-tab Beamer history is preserved',
    (tester) async {
      SidebarWakeQueueTestHooks.navigatorOverride = null;

      final mockNav = MockNavService();
      final mockDelegate = _RecordingBeamerDelegate();
      when(() => mockNav.index).thenReturn(6); // already on Settings
      when(() => mockNav.settingsIndex).thenReturn(6);
      when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
      when(
        () => mockNav.persistNamedRoute(any()),
      ).thenAnswer((_) async {});

      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(mockNav);
      addTearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'agent-stay',
              displayName: 'Kit',
              eta: const Duration(seconds: 30),
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      await tester.tap(find.text('Kit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(() => mockNav.setIndex(any()));
      expect(mockDelegate.beamed, ['/settings/agents/instances/agent-stay']);
    },
  );

  testWidgets(
    'tapping the header link icon routes through the production NavService '
    'when no test override is registered',
    (tester) async {
      SidebarWakeQueueTestHooks.navigatorOverride = null;

      final mockNav = MockNavService();
      final mockDelegate = _RecordingBeamerDelegate();
      when(() => mockNav.index).thenReturn(0);
      when(() => mockNav.settingsIndex).thenReturn(6);
      when(() => mockNav.setIndex(any())).thenReturn(null);
      when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
      when(
        () => mockNav.persistNamedRoute(any()),
      ).thenAnswer((_) async {});

      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(mockNav);
      addTearDown(() {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
      });

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'a-1',
              displayName: 'Laura',
              eta: const Duration(seconds: 28),
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      await tester.tap(find.byIcon(Icons.open_in_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mockNav.setIndex(6)).called(1);
      verify(
        () => mockNav.persistNamedRoute(kSidebarWakeQueueListRoute),
      ).called(1);
      expect(mockDelegate.beamed, [kSidebarWakeQueueListRoute]);
    },
  );

  testWidgets(
    'cancel button shows a spinner while clearScheduledWake is in flight, '
    'and resets when the future completes',
    (tester) async {
      final agentService = MockAgentService();
      final completer = Completer<void>();
      when(
        () => agentService.clearScheduledWake(any()),
      ).thenAnswer((_) => completer.future);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            [
              makeWake(
                agentId: 'agent-pending-cancel',
                displayName: 'Kit',
                eta: const Duration(hours: 1),
                type: PendingWakeType.scheduled,
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      // Single-frame pump: pumpAndSettle would hang on the spinner.
      await tester.pump();

      // Spinner is visible while the cancel future is in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      // Single-frame pumps clear the spinner without waiting for the
      // 1Hz countdown ticker (which never settles).
      await tester.pump();
      await tester.pump();

      // Spinner clears once the cancel resolves.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'cancel button swallows errors from clearScheduledWake so the spinner '
    'still resets and the row keeps responding',
    (tester) async {
      final agentService = MockAgentService();
      when(
        () => agentService.clearScheduledWake(any()),
      ).thenAnswer((_) => Future<void>.error(StateError('boom')));

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            [
              makeWake(
                agentId: 'agent-err',
                displayName: 'Sage',
                eta: const Duration(hours: 1),
                type: PendingWakeType.scheduled,
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Spinner has reset even though the cancel future errored.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      verify(
        () => agentService.clearScheduledWake('agent-err'),
      ).called(1);
    },
  );

  testWidgets(
    'a second cancel tap while the first is still in flight is a no-op '
    '(the early-return guard in `_cancelWake`)',
    (tester) async {
      final agentService = MockAgentService();
      final completer = Completer<void>();
      when(
        () => agentService.clearScheduledWake(any()),
      ).thenAnswer((_) => completer.future);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            [
              makeWake(
                agentId: 'agent-double',
                displayName: 'Iris',
                eta: const Duration(hours: 1),
                type: PendingWakeType.scheduled,
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      // Single-frame pump: pumpAndSettle would hang on the spinner.
      await tester.pump();

      // Spinner is now showing; the tooltip target is gone because
      // `_CancelWakeButton` has swapped its contents.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Issue a real second tap on the spinner's centre. The spinner
      // SizedBox has no gesture detector, so the cancel service must
      // not be invoked a second time. This actually exercises the
      // early-return path that protects `_cancelWake` if the button
      // ever regains hit-testability mid-flight (regression guard).
      await tester.tapAt(
        tester.getCenter(find.byType(CircularProgressIndicator)),
      );
      // Single-frame pumps: pumpAndSettle would hang on the spinner.
      await tester.pump();

      // Still in flight — service called exactly once so far.
      verify(
        () => agentService.clearScheduledWake('agent-double'),
      ).called(1);

      completer.complete();
      await tester.pump();
      await tester.pump();

      // No additional invocation after the in-flight call settles.
      verifyNever(() => agentService.clearScheduledWake(any()));
    },
  );

  testWidgets(
    'ongoing-wake row shows the linked task title and live elapsed pill',
    (tester) async {
      final startedAt = fixedNow.subtract(const Duration(seconds: 12));
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            const [],
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-running',
                title: 'Refine sidebar',
                startedAt: startedAt,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      // Header includes the running wake in the count.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Refine sidebar'), findsOneWidget);
      expect(find.text('00:12'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the trailing × on an ongoing wake calls abortRunningWake on '
    'the agent service',
    (tester) async {
      final agentService = MockAgentService();
      when(() => agentService.abortRunningWake(any())).thenReturn(true);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            const [],
            agentService: agentService,
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-running',
                title: 'Refine sidebar',
                startedAt: fixedNow.subtract(const Duration(seconds: 5)),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      // Single-frame pump: pumpAndSettle would hang on the spinner that
      // replaces the × once the abort signal is delivered.
      await tester.pump();

      verify(() => agentService.abortRunningWake('agent-running')).called(1);
      verifyNever(() => agentService.cancelPendingWake(any()));
      verifyNever(() => agentService.clearScheduledWake(any()));
    },
  );

  testWidgets(
    'when abortRunningWake returns false (agent already stopped) the row '
    'leaves the × in place — covers the `didSignal == false` branch where '
    'no spinner should appear because there is nothing in flight',
    (tester) async {
      final agentService = MockAgentService();
      when(() => agentService.abortRunningWake(any())).thenReturn(false);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            const [],
            agentService: agentService,
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-already-stopped',
                title: 'Idle row',
                startedAt: fixedNow,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      final cancelTooltip = element.messages.sidebarWakesCancelTooltip;

      await tester.tap(find.byTooltip(cancelTooltip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => agentService.abortRunningWake('agent-already-stopped'),
      ).called(1);

      // didSignal=false → _cancelling stays false → no spinner, the ×
      // remains tappable so the user can retry once the running-set
      // stream catches up.
      expect(find.byTooltip(cancelTooltip), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'after the × is tapped on an ongoing wake the row swaps the cancel '
    'button for an in-progress spinner, so the user gets feedback while '
    'the abort is in flight and a rapid second tap on the same widget '
    'cannot fire a second abort before the orchestrator releases the lock',
    (tester) async {
      final agentService = MockAgentService();
      when(() => agentService.abortRunningWake(any())).thenReturn(true);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            const [],
            agentService: agentService,
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-running',
                title: 'Stuck wake',
                startedAt: fixedNow,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      final cancelTooltip = element.messages.sidebarWakesCancelTooltip;

      // First tap fires abort + flips _cancelling → spinner replaces ×.
      await tester.tap(find.byTooltip(cancelTooltip));
      // Single-frame pump: pumpAndSettle would hang on the spinner.
      await tester.pump();

      verify(() => agentService.abortRunningWake('agent-running')).called(1);

      // The cancel × is gone (replaced by the spinner), so any further
      // taps on the cancel control are physically impossible until the
      // running-set stream emits and the row is rebuilt or torn down.
      // Belt-and-braces: try to tap the tooltip and verify nothing
      // additional reaches the service.
      expect(find.byTooltip(cancelTooltip), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      verifyNoMoreInteractions(agentService);
    },
  );

  testWidgets(
    'ongoing-wake row updates its title live when '
    'pendingWakeTargetTitleProvider re-emits — covers the rename '
    'staleness case where renaming the task left the WAKES widget '
    'showing the old title until the agent stopped',
    (tester) async {
      final startedAt = fixedNow.subtract(const Duration(seconds: 4));
      final controller = StreamController<String?>();
      addTearDown(controller.close);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SidebarWakeQueue(),
            theme: DesignSystemTheme.dark(),
            overrides: [
              pendingWakeRecordsProvider.overrideWith(
                (ref) async => const <PendingWakeRecord>[],
              ),
              ongoingWakeRecordsProvider.overrideWith(
                (ref) async => [
                  OngoingWakeRecord(
                    agentId: 'agent-rename',
                    title: 'snapshot fallback',
                    subjectId: 'task-rename',
                    startedAt: startedAt,
                  ),
                ],
              ),
              pendingWakeTargetTitleProvider(
                'task-rename',
              ).overrideWith((ref) => controller.stream.first),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        controller.add('GLaDOS');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('GLaDOS'), findsOneWidget);
        expect(find.text('snapshot fallback'), findsNothing);
      });
    },
  );

  testWidgets(
    'ongoing-wake row falls back to record.title when '
    'pendingWakeTargetTitleProvider yields null or empty — covers both '
    'the production "no usable title" path (provider returns null) and '
    'the defence-in-depth check the widget keeps in case a provider '
    'override slips through with a trimmed-to-empty value',
    (tester) async {
      final startedAt = fixedNow.subtract(const Duration(seconds: 4));

      Future<void> pumpWithProviderResult(FutureOr<String?> result) async {
        await withClock(Clock.fixed(fixedNow), () async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const SidebarWakeQueue(),
              theme: DesignSystemTheme.dark(),
              overrides: [
                pendingWakeRecordsProvider.overrideWith(
                  (ref) async => const <PendingWakeRecord>[],
                ),
                ongoingWakeRecordsProvider.overrideWith(
                  (ref) async => [
                    OngoingWakeRecord(
                      agentId: 'agent-stale',
                      title: 'agent-stale',
                      subjectId: 'task-blank',
                      startedAt: startedAt,
                    ),
                  ],
                ),
                pendingWakeTargetTitleProvider(
                  'task-blank',
                ).overrideWith((ref) async => result),
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });
      }

      // 1. Provider returns null — the production case: empty/whitespace
      // titles are normalised to null inside pendingWakeTargetTitleProvider.
      await pumpWithProviderResult(null);
      expect(find.text('agent-stale'), findsOneWidget);

      // 2. Provider returns an empty string — the widget's own
      // `liveSubjectTitle.isNotEmpty` guard must still fall through to the
      // snapshot fallback even if a future change to the provider lets an
      // empty string escape its trim/normalise path.
      await pumpWithProviderResult('');
      expect(find.text('agent-stale'), findsOneWidget);
    },
  );

  testWidgets(
    "tapping an ongoing wake routes to that agent's instance page",
    (tester) async {
      String? captured;
      SidebarWakeQueueTestHooks.navigatorOverride = (path) => captured = path;

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject(
            const [],
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-running',
                title: 'Live wake',
                startedAt: fixedNow,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      await tester.tap(find.text('Live wake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(captured, '/settings/agents/instances/agent-running');
    },
  );

  // The leading agent-letter avatar was removed from the sidebar wake
  // row by the design refresh — the row now reads as just template
  // name + ETA + cancel ×. The avatar-specific behaviour tests
  // (`?` fallback, emoji-rune handling) are intentionally gone with
  // it; they verified a widget that no longer exists.

  group('sidebarWakeQueueHasVisibleContent', () {
    Future<bool> evaluate(
      WidgetTester tester, {
      List<PendingWakeRecord> wakes = const [],
      List<OngoingWakeRecord> ongoing = const [],
      bool wakesLoading = false,
      bool ongoingLoading = false,
    }) async {
      late bool result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingWakeRecordsProvider.overrideWith(
              (ref) async {
                if (wakesLoading) {
                  return Completer<List<PendingWakeRecord>>().future;
                }
                return wakes;
              },
            ),
            ongoingWakeRecordsProvider.overrideWith(
              (ref) async {
                if (ongoingLoading) {
                  return Completer<List<OngoingWakeRecord>>().future;
                }
                return ongoing;
              },
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              result = sidebarWakeQueueHasVisibleContent(ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      return result;
    }

    testWidgets(
      'returns false while both providers are still loading — the helper '
      'must treat null AsyncValues as empty so the composer does not '
      'reserve a phantom spacer above the timer card',
      (tester) async {
        final visible = await evaluate(
          tester,
          wakesLoading: true,
          ongoingLoading: true,
        );
        expect(visible, isFalse);
      },
    );

    testWidgets(
      'returns false when both providers resolve to empty lists',
      (tester) async {
        final visible = await evaluate(tester);
        expect(visible, isFalse);
      },
    );

    testWidgets(
      'returns true when an ongoing wake is active, even with no pending '
      'records — the ongoing branch short-circuits before the cutoff scan',
      (tester) async {
        await withClock(Clock.fixed(fixedNow), () async {
          final visible = await evaluate(
            tester,
            ongoing: [
              OngoingWakeRecord(
                agentId: 'agent-running',
                title: 'Refine sidebar',
                startedAt: fixedNow.subtract(const Duration(seconds: 5)),
              ),
            ],
          );
          expect(visible, isTrue);
        });
      },
    );

    testWidgets(
      'returns true when at least one pending wake falls inside the '
      '1h lookahead window',
      (tester) async {
        await withClock(Clock.fixed(fixedNow), () async {
          final visible = await evaluate(
            tester,
            wakes: [
              makeWake(
                agentId: 'a-1',
                displayName: 'Laura',
                eta: const Duration(minutes: 5),
              ),
            ],
          );
          expect(visible, isTrue);
        });
      },
    );

    testWidgets(
      'returns false when every pending wake is past the 1h lookahead '
      'cutoff — those rows are hidden from the sidebar, so the composer '
      'must not reserve a spacer for them',
      (tester) async {
        await withClock(Clock.fixed(fixedNow), () async {
          final visible = await evaluate(
            tester,
            wakes: [
              makeWake(
                agentId: 'a-1',
                displayName: 'Laura',
                eta: const Duration(hours: 9),
              ),
              makeWake(
                agentId: 'a-2',
                displayName: 'Iris',
                eta: const Duration(hours: 12),
              ),
            ],
          );
          expect(visible, isFalse);
        });
      },
    );
  });
}

/// Captures `beamToNamed` calls without spinning up a real Beamer
/// router. Used to verify the production navigation paths in
/// `_navigateToAgentRoute` without standing up the full Lotti router.
class _RecordingBeamerDelegate extends BeamerDelegate {
  _RecordingBeamerDelegate()
    : super(
        locationBuilder: RoutesLocationBuilder(
          routes: {'*': (_, _, _) => const SizedBox.shrink()},
        ).call,
      );

  final List<String> beamed = <String>[];

  @override
  void beamToNamed(
    String uri, {
    Object? data,
    Object? routeState,
    bool beamBackOnPop = false,
    bool popBeamLocationOnPop = false,
    bool stacked = true,
    bool replaceRouteInformation = false,
    TransitionDelegate<dynamic>? transitionDelegate,
    String? popToNamed,
  }) {
    beamed.add(uri);
  }
}
