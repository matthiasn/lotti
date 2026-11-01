import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/test_doubles/mock_day_agent.dart';

/// A capture controller with no microphone behind it: it holds what it is
/// told, as the typed path does.
class _TypedCapture extends CaptureController {
  @override
  CaptureState build() => const CaptureState.idle();

  @override
  void startTyping() => state = const CaptureState(
    phase: CapturePhase.captured,
    transcript: '',
    amplitudes: [],
  );
}

void main() {
  final today = DateTime(2026, 11);

  group('frontDayPlanningIntent', () {
    test("refines today's plan with the words sent at once", () {
      final plan = DraftPlan(
        dayDate: today,
        blocks: const [],
        bands: const [],
        capacityMinutes: 0,
        scheduledMinutes: 0,
      );
      final intent =
          frontDayPlanningIntent(plan, 'Move the count') as DayPlanningAdapt;
      expect(intent.draft, same(plan));
      expect(intent.initialTranscript, 'Move the count');
    });

    test('with no plan yet, starts one from the words, typed in', () {
      final intent =
          frontDayPlanningIntent(null, 'Move the count') as DayPlanningCreate;
      expect(intent.initialTranscript, 'Move the count');
    });
  });

  testWidgets('the planner opens the planning for today with the words, and '
      'a dismissed planning plans nothing', (tester) async {
    DateTime? planned;
    await withClock(Clock.fixed(today.add(const Duration(hours: 9))), () async {
      await tester.pumpWidget(
        makeTestableWidget(
          Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final plan = ref.read(frontDayPlannerProvider);
                  planned = await plan(context, 'Move the count');
                },
                child: const Text('plan'),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(420, 900)),
          overrides: [
            dayAgentProvider.overrideWithValue(
              MockDayAgent(
                parseLatency: Duration.zero,
                pendingLatency: Duration.zero,
              ),
            ),
            captureControllerProvider.overrideWith(_TypedCapture.new),
            dailyOsActualTimeBlocksProvider.overrideWith(
              (ref, date) async => const [],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
          ],
        ),
      );
      await tester.tap(find.text('plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    // No plan today: the capture of a new one, with the words typed in.
    final content = find.byType(CaptureModalContent);
    expect(content, findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(content),
      ).read(captureControllerProvider).transcript,
      'Move the count',
    );

    Navigator.of(tester.element(content), rootNavigator: true).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(planned, isNull);
  });

  testWidgets('a surface gone before the plan is read opens nothing and '
      'plans nothing', (tester) async {
    final read = Completer<DraftPlan?>();
    DateTime? planned;
    await tester.pumpWidget(
      makeTestableWidget(
        Consumer(
          builder: (context, ref, _) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final plan = ref.read(frontDayPlannerProvider);
                planned = await plan(context, 'Move the count');
              },
              child: const Text('plan'),
            ),
          ),
        ),
        overrides: [dayAgentProvider.overrideWithValue(_SlowPlan(read))],
      ),
    );
    await tester.tap(find.text('plan'));
    await tester.pump();

    // The surface closes while today's plan is still being read.
    await tester.pumpWidget(const SizedBox.shrink());
    read.complete(null);
    await tester.pump();

    expect(planned, isNull);
    expect(find.byType(CaptureModalContent), findsNothing);
  });

  testWidgets('the project opener shows the project form titled with the '
      'words, and a form closed makes no project', (tester) async {
    // The form resolves categories through the locator.
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
    addTearDown(tearDownTestGetIt);
    var done = false;
    String? created;
    await tester.pumpWidget(
      makeTestableWidget(
        Consumer(
          builder: (context, ref, _) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final create = ref.read(frontNewProjectProvider);
                created = await create(context, 'Rebuild the feeders');
                done = true;
              },
              child: const Text('new'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('new'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final form = find.byType(ProjectCreateForm);
    expect(form, findsOneWidget);
    expect(
      find.descendant(of: form, matching: find.text('Rebuild the feeders')),
      findsOne,
    );

    Navigator.of(tester.element(form)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
    expect(created, isNull);
  });
}

/// A day agent still reading today's plan when the surface goes away.
class _SlowPlan extends MockDayAgent {
  _SlowPlan(this._read);

  final Completer<DraftPlan?> _read;

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) => _read.future;
}
