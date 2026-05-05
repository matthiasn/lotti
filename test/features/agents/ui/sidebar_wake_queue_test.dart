import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) {
    return makeTestableWidgetWithScaffold(
      const SidebarWakeQueue(),
      theme: DesignSystemTheme.dark(),
      overrides: [
        pendingWakeRecordsProvider.overrideWith((ref) async => records),
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
    'while wakes are loading, the queue surfaces the empty header (so '
    'enabling the section gives the user immediate feedback) but does not '
    'render any wake rows yet',
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
        findsOneWidget,
      );
      expect(find.text('0'), findsOneWidget);
      expect(
        find.text('${element.messages.sidebarWakesOpenList} →'),
        findsOneWidget,
      );

      completer.complete(const []);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'renders an empty header and "Open list" link when no wakes are pending '
    '— matches the design handoff "no layout shift when empty, just hide '
    'rows, keep header"',
    (tester) async {
      await tester.pumpWidget(buildSubject(const []));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SidebarWakeQueue));
      expect(
        find.text(element.messages.sidebarWakesHeader.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('0'), findsOneWidget);
      expect(
        find.text('${element.messages.sidebarWakesOpenList} →'),
        findsOneWidget,
      );
      // No row InkWell, but the "Open list" link still has its own InkWell.
      expect(find.byType(InkWell), findsOneWidget);
    },
  );

  testWidgets('renders header count, two upcoming rows, and +N more link', (
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
    expect(find.text('5'), findsOneWidget);

    // Only the first two wakes are rendered as rows.
    expect(find.text('Laura'), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(find.text('Kit'), findsNothing);

    // Imminent ETA renders as mm:ss.
    expect(find.text('00:28'), findsOneWidget);
    expect(find.text('00:50'), findsOneWidget);

    // +N more affordance shows the rollover count, not the total.
    // The trailing arrow is appended in the widget (not in the ARB),
    // so we assert against the rendered composition.
    expect(find.text('${messages.sidebarWakesMore(3)} →'), findsOneWidget);
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
    });

    final element = tester.element(find.byType(SidebarWakeQueue));
    expect(find.text(element.messages.sidebarWakesNow), findsOneWidget);
  });

  testWidgets('formats ETAs over an hour as "Xh MMm"', (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        buildSubject([
          makeWake(
            agentId: 'a-1',
            displayName: 'Laura',
            eta: const Duration(hours: 2, minutes: 7),
          ),
        ]),
      );
      await tester.pump();
    });

    expect(find.text('2h 07m'), findsOneWidget);
  });

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
    });

    await tester.tap(find.text('Laura'));
    await tester.pump();

    expect(captured, '/settings/agents/instances/agent-xyz');
  });

  testWidgets('tapping +N more navigates to the pending wakes list', (
    tester,
  ) async {
    String? captured;
    SidebarWakeQueueTestHooks.navigatorOverride = (path) => captured = path;

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        buildSubject([
          for (var i = 0; i < 5; i++)
            makeWake(
              agentId: 'agent-$i',
              displayName: 'Agent $i',
              eta: Duration(seconds: 30 + i),
            ),
        ]),
      );
      await tester.pump();
    });

    final element = tester.element(find.byType(SidebarWakeQueue));
    await tester.tap(find.text('${element.messages.sidebarWakesMore(3)} →'));
    await tester.pump();

    expect(captured, kSidebarWakeQueueListRoute);
  });

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
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pump();

      verify(() => agentService.cancelPendingWake('agent-pending')).called(1);
      verifyNever(() => agentService.clearScheduledWake(any()));
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
              makeWake(
                agentId: 'agent-scheduled',
                displayName: 'Kit',
                eta: const Duration(hours: 4),
                type: PendingWakeType.scheduled,
              ),
            ],
            agentService: agentService,
          ),
        );
        await tester.pump();
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pumpAndSettle();

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
      });

      await tester.tap(find.text('Laura'));
      await tester.pump();

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
      });

      await tester.tap(find.text('Kit'));
      await tester.pump();

      verifyNever(() => mockNav.setIndex(any()));
      expect(mockDelegate.beamed, ['/settings/agents/instances/agent-stay']);
    },
  );

  testWidgets(
    'tapping the Open list link routes through the production NavService '
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

      await tester.pumpWidget(buildSubject(const []));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.text('${element.messages.sidebarWakesOpenList} →'),
      );
      await tester.pump();

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
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pump();

      // Spinner is visible while the cancel future is in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

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
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
      await tester.pumpAndSettle();

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
      });

      final element = tester.element(find.byType(SidebarWakeQueue));
      await tester.tap(
        find.byTooltip(element.messages.sidebarWakesCancelTooltip),
      );
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
      await tester.pump();

      // Still in flight — service called exactly once so far.
      verify(
        () => agentService.clearScheduledWake('agent-double'),
      ).called(1);

      completer.complete();
      await tester.pumpAndSettle();

      // No additional invocation after the in-flight call settles.
      verifyNever(() => agentService.clearScheduledWake(any()));
    },
  );

  testWidgets(
    '_AgentAvatar renders "?" when the display name is empty / whitespace',
    (tester) async {
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'a-blank',
              displayName: '   ',
              eta: const Duration(seconds: 30),
            ),
          ]),
        );
        await tester.pump();
      });

      // Falls back to '?' since the trimmed name is empty.
      expect(find.text('?'), findsOneWidget);
    },
  );

  testWidgets(
    '_AgentAvatar uses runes.first so emoji-prefixed display names render '
    'the full Unicode codepoint instead of half a UTF-16 surrogate pair',
    (tester) async {
      // 🤖 is U+1F916, encoded as two UTF-16 code units in Dart strings.
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          buildSubject([
            makeWake(
              agentId: 'a-emoji',
              displayName: '🤖 Bot',
              eta: const Duration(seconds: 30),
            ),
          ]),
        );
        await tester.pump();
      });

      // The avatar tile renders the full robot emoji glyph (single rune).
      expect(find.text('🤖'), findsOneWidget);
    },
  );
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
