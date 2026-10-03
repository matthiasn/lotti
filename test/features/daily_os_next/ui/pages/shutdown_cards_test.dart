import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_shutdown_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../test_doubles/mock_day_agent.dart';

final _forDate = DateTime(2026, 5, 25);

/// Scripted agent whose reflection and note behaviour each test controls.
class _CardAgent extends MockDayAgent {
  _CardAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final reflections = <String>[];
  Error? failReflectionWith;
  Error? failEnsureWith;
  int noteCalls = 0;
  Object? Function(int call)? noteFailure;

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
  }) async {
    final failure = failReflectionWith;
    if (failure != null) throw failure;
    reflections.add(text);
  }

  @override
  Future<String> ensureReflectionEntry({required DateTime forDate}) async {
    final failure = failEnsureWith;
    if (failure != null) throw failure;
    return 'reflection-entry';
  }

  @override
  Future<TomorrowNote> generateTomorrowNote({required DateTime forDate}) async {
    noteCalls++;
    switch (noteFailure?.call(noteCalls)) {
      case final Exception failure:
        throw failure;
      case final Error failure:
        throw failure;
    }
    return TomorrowNote(body: 'Note $noteCalls');
  }
}

Widget _host(_CardAgent agent, Widget child) => ProviderScope(
  overrides: [dayAgentProvider.overrideWithValue(agent)],
  child: makeTestableWidget2(
    Consumer(
      builder: (context, ref, _) {
        // Keep the controller alive the way the page does.
        ref.watch(shutdownControllerProvider(_forDate));
        return Scaffold(body: SingleChildScrollView(child: child));
      },
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('MetricsCard', () {
    testWidgets('shows a dash and a rating hint when nothing was rated', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          const MetricsCard(
            metrics: ShutdownMetrics(
              focusMinutes: 125,
              flowSessions: 1,
              contextSwitches: 4,
            ),
          ),
        ),
      );
      final messages = tester.element(find.byType(MetricsCard)).messages;

      expect(find.text('2h 5m'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextShutdownMetricEnergyNoRatings),
        findsOneWidget,
      );
      // No week average: no comparison line under the switches.
      expect(find.textContaining('this week'), findsNothing);
    });

    testWidgets('shows the measured energy and both week comparisons', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          const MetricsCard(
            metrics: ShutdownMetrics(
              focusMinutes: 120,
              flowSessions: 2,
              contextSwitches: 3,
              contextSwitchesWeekAvg: 5.25,
              energyScore: 6.5,
              energyDeltaVsWeek: -0.4,
            ),
          ),
        ),
      );
      final messages = tester.element(find.byType(MetricsCard)).messages;

      expect(find.text('2h'), findsOneWidget);
      expect(find.text('6.5'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextShutdownMetricEnergyDelta('⬇ 0.4')),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextShutdownMetricSwitchesAvg('5.3')),
        findsOneWidget,
      );
    });

    testWidgets('an energy score without a week baseline has no delta', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          const MetricsCard(
            metrics: ShutdownMetrics(
              focusMinutes: 0,
              flowSessions: 0,
              contextSwitches: 0,
              energyScore: 8,
            ),
          ),
        ),
      );
      final messages = tester.element(find.byType(MetricsCard)).messages;

      expect(find.text('8.0'), findsOneWidget);
      expect(find.textContaining('vs. week'), findsNothing);
      expect(
        find.text(messages.dailyOsNextShutdownMetricEnergyNoRatings),
        findsNothing,
      );
    });
  });

  group('ReflectionCard', () {
    testWidgets('Speak records under the day reflection entry', (
      tester,
    ) async {
      final agent = _CardAgent();
      String? recordedUnder;
      await tester.pumpWidget(
        _host(
          agent,
          ReflectionCard(
            forDate: _forDate,
            recordVoice: (context, entryId) async {
              recordedUnder = entryId;
              return 'audio-1';
            },
          ),
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ReflectionCard)).messages;

      await tester.tap(find.text(messages.dailyOsNextShutdownReflectionSpeak));
      await _settle(tester);

      expect(recordedUnder, 'reflection-entry');
      expect(
        find.text(messages.dailyOsNextShutdownReflectionThanks),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled recording keeps the card open', (tester) async {
      final agent = _CardAgent();
      await tester.pumpWidget(
        _host(
          agent,
          ReflectionCard(
            forDate: _forDate,
            recordVoice: (context, entryId) async => null,
          ),
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ReflectionCard)).messages;

      await tester.tap(find.text(messages.dailyOsNextShutdownReflectionSpeak));
      await _settle(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextShutdownReflectionThanks),
        findsNothing,
      );
    });

    testWidgets('a reflection entry that cannot be created says so', (
      tester,
    ) async {
      final agent = _CardAgent()..failEnsureWith = StateError('db locked');
      var recorderOpened = false;
      await tester.pumpWidget(
        _host(
          agent,
          ReflectionCard(
            forDate: _forDate,
            recordVoice: (context, entryId) async {
              recorderOpened = true;
              return 'audio-1';
            },
          ),
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ReflectionCard)).messages;

      await tester.tap(find.text(messages.dailyOsNextShutdownReflectionSpeak));
      await _settle(tester);

      expect(recorderOpened, isFalse);
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
    });

    testWidgets('a failed save keeps the text and says so', (tester) async {
      final agent = _CardAgent()..failReflectionWith = StateError('db locked');
      await tester.pumpWidget(
        _host(agent, ReflectionCard(forDate: _forDate)),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ReflectionCard)).messages;

      await tester.enterText(find.byType(TextField), 'Sharp morning');
      await tester.tap(find.text(messages.dailyOsNextShutdownReflectionSave));
      await _settle(tester);

      expect(find.text('Sharp morning'), findsOneWidget);
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
    });
  });

  group('TomorrowNoteCard', () {
    testWidgets('shows the note once written', (tester) async {
      await tester.pumpWidget(
        _host(_CardAgent(), TomorrowNoteCard(forDate: _forDate)),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await _settle(tester);

      expect(find.text('Note 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('asks for an AI provider when none is configured', (
      tester,
    ) async {
      final agent = _CardAgent()
        ..noteFailure = (_) => const TomorrowNoteUnavailableException(
          TomorrowNoteFailure.noInferenceProvider,
        );
      await tester.pumpWidget(
        _host(agent, TomorrowNoteCard(forDate: _forDate)),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(TomorrowNoteCard)).messages;

      expect(
        find.text(messages.dailyOsNextShutdownTomorrowNoProvider),
        findsOneWidget,
      );
      expect(find.text(messages.dailyOsNextDraftingRetry), findsNothing);
    });

    testWidgets('offers a retry after another failure, which recovers', (
      tester,
    ) async {
      final agent = _CardAgent()
        ..noteFailure = (call) => call == 1 ? StateError('offline') : null;
      await tester.pumpWidget(
        _host(agent, TomorrowNoteCard(forDate: _forDate)),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(TomorrowNoteCard)).messages;
      expect(
        find.text(messages.dailyOsNextShutdownTomorrowError),
        findsOneWidget,
      );

      await tester.tap(find.text(messages.dailyOsNextDraftingRetry));
      await _settle(tester);

      expect(find.text('Note 2'), findsOneWidget);
    });
  });

  group('ShutdownFooter', () {
    testWidgets('Close the day writes a fresh note, then leaves', (
      tester,
    ) async {
      final agent = _CardAgent();
      var popped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dayAgentProvider.overrideWithValue(agent)],
          child: makeTestableWidget2(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: TomorrowNoteCard(forDate: _forDate),
                        bottomNavigationBar: ShutdownFooter(forDate: _forDate),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(agent.noteCalls, 1);
      final messages = tester.element(find.byType(ShutdownFooter)).messages;

      await tester.tap(find.text(messages.dailyOsNextShutdownCloseDay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      expect(agent.noteCalls, 2);
      expect(popped, isTrue);
    });

    testWidgets('a note that cannot be written does not keep the day open', (
      tester,
    ) async {
      final agent = _CardAgent()
        ..noteFailure = (call) => call > 1 ? StateError('offline') : null;
      var popped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dayAgentProvider.overrideWithValue(agent)],
          child: makeTestableWidget2(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: TomorrowNoteCard(forDate: _forDate),
                        bottomNavigationBar: ShutdownFooter(forDate: _forDate),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final messages = tester.element(find.byType(ShutdownFooter)).messages;

      await tester.tap(find.text(messages.dailyOsNextShutdownCloseDay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      expect(popped, isTrue);
    });
  });
}
