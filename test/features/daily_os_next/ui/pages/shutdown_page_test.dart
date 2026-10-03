import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_cards.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_doubles/mock_day_agent.dart';

/// Applies the standard tall-desktop view geometry every test needs and
/// registers its reset.
void _setView(
  WidgetTester tester, {
  Size size = const Size(1280, 1100),
}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Lets the day facts load, then the tomorrow note the page starts loading
/// once its body first builds.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(1280, 1100),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: MediaQueryData(size: size, textScaler: textScaler),
    ),
  );
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
);

/// Agent whose tomorrow note is fully controlled by the test.
class _TomorrowNoteAgent extends MockDayAgent {
  _TomorrowNoteAgent(this.note)
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final TomorrowNote note;

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => note;
}

class _LongCarryoverCategoryAgent extends MockDayAgent {
  _LongCarryoverCategoryAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  static const categoryName =
      'A category name that is much wider than a compact phone card';

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: [
      CarryoverItem(
        taskId: 'long-category-task',
        title: 'Carry this task forward',
        category: const DayAgentCategory(
          id: 'cat-long',
          name: categoryName,
          colorHex: '3366CC',
        ),
        loggedMinutes: 0,
        suggestedDate: DateTime(2026, 5, 26),
      ),
    ],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
    ),
  );
}

/// Agent whose day has nothing recorded and nothing left open.
class _EmptyDayAgent extends MockDayAgent {
  _EmptyDayAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
    ),
  );
}

/// Agent whose carryover writes fail.
class _FailingCarryoverAgent extends MockDayAgent {
  _FailingCarryoverAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  @override
  Future<void> recordCarryoverDecision({
    required DateTime forDate,
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async => throw StateError('offline');
}

/// The page labels the next day "Tomorrow" relative to the wall clock.
final _evening = Clock.fixed(DateTime(2026, 5, 25, 18));

void main() {
  group('ShutdownPage', () {
    testWidgets('renders completed + carryover + tomorrow content', (
      tester,
    ) async {
      _setView(tester);

      final agent = _fastAgent();
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await _settle(tester);

      // Mock returns 2 completed items + 2 carryover items.
      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);
      expect(find.text('Morning run · 5km'), findsOneWidget);
      expect(find.text('Finish the Onboarding doc'), findsOneWidget);
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      // For-tomorrow note body — the mock writes a paragraph.
      expect(find.textContaining("I'll start the draft"), findsOneWidget);
    });

    testWidgets('keeps every footer action inside a 402dp phone viewport', (
      tester,
    ) async {
      const size = Size(402, 874);
      _setView(tester, size: size);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
          size: size,
        ),
      );
      await _settle(tester);

      final messages = tester.element(find.byType(ShutdownPage)).messages;
      final actions = [
        find.widgetWithText(TextButton, messages.dailyOsNextDayBack),
        find.widgetWithText(
          TextButton,
          messages.dailyOsNextShutdownSaveAndClose,
        ),
        find.widgetWithText(
          FilledButton,
          messages.dailyOsNextShutdownCloseDay,
        ),
      ];
      for (final action in actions) {
        expect(action, findsOneWidget);
        final bounds = tester.getRect(action);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('long carryover category stays bounded on a compact phone', (
      tester,
    ) async {
      const size = Size(360, 640);
      _setView(tester, size: size);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [
            dayAgentProvider.overrideWithValue(_LongCarryoverCategoryAgent()),
          ],
          size: size,
        ),
      );
      await _settle(tester);

      expect(
        find.text(_LongCarryoverCategoryAgent.categoryName),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps scaled metric text inside the metrics card', (
      tester,
    ) async {
      const size = Size(600, 1200);
      _setView(tester, size: size);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
          size: size,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await _settle(tester);

      final metricsCard = find.byType(MetricsCard);
      expect(metricsCard, findsOneWidget);
      final metricsBounds = tester.getRect(metricsCard);
      final messages = tester.element(metricsCard).messages;
      for (final label in [
        messages.dailyOsNextShutdownMetricFocus,
        messages.dailyOsNextShutdownMetricFlow,
        messages.dailyOsNextShutdownMetricSwitches,
        messages.dailyOsNextShutdownMetricEnergy,
      ]) {
        final labelFinder = find.text(label);
        expect(labelFinder, findsOneWidget);
        final labelBounds = tester.getRect(labelFinder);
        expect(labelBounds.top, greaterThanOrEqualTo(metricsBounds.top));
        expect(labelBounds.bottom, lessThanOrEqualTo(metricsBounds.bottom));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps shutdown content during provider refreshes', (
      tester,
    ) async {
      _setView(tester);

      final agent = RefreshBlockingShutdownAgent();
      addTearDown(() {
        if (!agent.pendingShutdownRefresh.isCompleted) {
          agent.pendingShutdownRefresh.complete(
            const (
              completed: <CompletedItem>[],
              carryover: <CarryoverItem>[],
              metrics: ShutdownMetrics(
                focusMinutes: 0,
                flowSessions: 0,
                contextSwitches: 0,
              ),
            ),
          );
        }
      });
      final date = DateTime(2026, 5, 25);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: date),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await _settle(tester);

      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(ShutdownPage)),
      ).invalidate(shutdownControllerProvider(date));
      await tester.pump();

      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders a localized error when shutdown loading fails', (
      tester,
    ) async {
      _setView(tester);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [
            dayAgentProvider.overrideWithValue(ThrowingShutdownAgent()),
          ],
        ),
      );
      await _settle(tester);

      final messages = tester.element(find.byType(ShutdownPage)).messages;
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
      expect(find.textContaining('shutdown unavailable'), findsNothing);
    });

    testWidgets('footer actions all pop the shutdown route', (tester) async {
      _setView(tester);

      final cases = <Finder Function(AppLocalizations)>[
        (messages) => find.widgetWithText(
          TextButton,
          messages.dailyOsNextDayBack,
        ),
        (messages) => find.widgetWithText(
          TextButton,
          messages.dailyOsNextShutdownSaveAndClose,
        ),
        (messages) => find.widgetWithText(
          FilledButton,
          messages.dailyOsNextShutdownCloseDay,
        ),
      ];

      for (final finderFor in cases) {
        final agent = _fastAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ShutdownPage(
                          forDate: DateTime(2026, 5, 25),
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);

        final messages = tester.element(find.byType(ShutdownPage)).messages;
        final control = finderFor(messages);
        await tester.ensureVisible(control);
        await tester.tap(control);
        // Close the day rewrites the note before it pops.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 800));

        expect(popped, isTrue);
        expect(find.byType(ShutdownPage), findsNothing);
      }
    });

    testWidgets(
      'the Tomorrow chip re-places the task and collapses its row',
      (tester) async {
        await withClock(_evening, () async {
          _setView(tester);
          await tester.pumpWidget(
            _wrap(
              ShutdownPage(forDate: DateTime(2026, 5, 25)),
              overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
            ),
          );
          await _settle(tester);
          final messages = tester.element(find.byType(ShutdownPage)).messages;
          final pickDate = find.text(
            messages.dailyOsNextShutdownCarryoverPickDate,
          );
          expect(pickDate, findsNWidgets(2));

          final tomorrow = find.widgetWithText(
            FilledButton,
            messages.dailyOsNextShutdownCarryoverTomorrow,
          );
          await tester.ensureVisible(tomorrow.first);
          await tester.tap(tomorrow.first);
          await _settle(tester);

          // One row now shows its decision instead of its three actions;
          // its pill names the day it moved to.
          expect(pickDate, findsOneWidget);
          expect(tomorrow, findsOneWidget);
          expect(
            find.text(messages.dailyOsNextShutdownCarryoverTomorrow),
            findsNWidgets(2),
          );
        });
      },
    );

    testWidgets(
      'AppBar back-arrow button pops the route',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        var popped = false;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ShutdownPage(
                          forDate: DateTime(2026, 5, 25),
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await _settle(tester);

        // Tap the leading back icon (not the footer TextButton).
        final backIcon = find.widgetWithIcon(
          IconButton,
          LottiIcons.back,
        );
        expect(backIcon, findsOneWidget);
        await tester.tap(backIcon);
        await tester.pump();
        // The push finished first, so the exit transition runs in full.
        await tester.pump(const Duration(milliseconds: 800));

        expect(popped, isTrue);
        expect(find.byType(ShutdownPage), findsNothing);
      },
    );

    testWidgets(
      'Pick a date moves the task to the picked day; Drop drops it',
      (tester) async {
        await withClock(_evening, () async {
          _setView(tester);
          await tester.pumpWidget(
            _wrap(
              ShutdownPage(forDate: DateTime(2026, 5, 25)),
              overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
            ),
          );
          await _settle(tester);
          final messages = tester.element(find.byType(ShutdownPage)).messages;

          final pickDate = find.text(
            messages.dailyOsNextShutdownCarryoverPickDate,
          );
          await tester.ensureVisible(pickDate.first);
          await tester.tap(pickDate.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final calendar = tester.widget<CalendarDatePicker>(
            find.byType(CalendarDatePicker),
          );
          // The picker starts on the suggested next day.
          expect(calendar.initialDate, DateTime(2026, 5, 26));
          calendar.onDateChanged(DateTime(2026, 5, 28));
          await tester.pump();
          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Thu, May 28'), findsOneWidget);

          final drop = find.text(messages.dailyOsNextShutdownCarryoverDrop);
          expect(drop, findsOneWidget);
          await tester.ensureVisible(drop);
          await tester.tap(drop);
          await _settle(tester);

          expect(
            find.text(messages.dailyOsNextShutdownCarryoverDropped),
            findsOneWidget,
          );
          expect(pickDate, findsNothing);
          expect(drop, findsNothing);
        });
      },
    );

    testWidgets('dismissing the date picker leaves the row undecided', (
      tester,
    ) async {
      _setView(tester);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ShutdownPage)).messages;
      final pickDate = find.text(messages.dailyOsNextShutdownCarryoverPickDate);

      await tester.ensureVisible(pickDate.first);
      await tester.tap(pickDate.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      Navigator.of(tester.element(find.byType(CalendarDatePicker))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(pickDate, findsNWidgets(2));
    });

    testWidgets('a failed carryover write says so and keeps the row open', (
      tester,
    ) async {
      _setView(tester);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [
            dayAgentProvider.overrideWithValue(_FailingCarryoverAgent()),
          ],
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ShutdownPage)).messages;
      final drop = find.text(messages.dailyOsNextShutdownCarryoverDrop);

      await tester.ensureVisible(drop.first);
      await tester.tap(drop.first);
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(messages.dailyOsNextGenericError),
        ),
        findsOneWidget,
      );
      expect(drop, findsNWidgets(2));
    });

    testWidgets('rows show their recorded facts', (tester) async {
      _setView(tester);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(_fastAgent())],
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ShutdownPage)).messages;

      expect(
        find.text(
          '${messages.dailyOsNextShutdownCompletedSessions(2)} · '
          '${messages.dailyOsNextShutdownCompletedDoneToday}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextShutdownCompletedSessions(1)),
        findsOneWidget,
      );
      expect(find.text('95m'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextShutdownCarryoverStarted(40)),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextShutdownCarryoverNotStarted),
        findsOneWidget,
      );
    });

    testWidgets('an empty day says so in both columns', (tester) async {
      _setView(tester);
      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [dayAgentProvider.overrideWithValue(_EmptyDayAgent())],
        ),
      );
      await _settle(tester);
      final messages = tester.element(find.byType(ShutdownPage)).messages;

      expect(
        find.text(messages.dailyOsNextShutdownCompletedEmpty),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextShutdownCarryoverEmpty),
        findsOneWidget,
      );
    });

    testWidgets(
      'submitting an empty reflection does not call the controller '
      'and leaves the form visible',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await _settle(tester);

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Leave the text field empty and tap Save.
        final skipBtn = find.text(messages.dailyOsNextShutdownReflectionSave);
        await tester.ensureVisible(skipBtn);
        await tester.tap(skipBtn);
        await _settle(tester);

        // The form should still be visible — no thanks text shown.
        expect(skipBtn, findsOneWidget);
        expect(
          find.text(messages.dailyOsNextShutdownReflectionThanks),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping Save with text records the reflection and shows thanks',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await _settle(tester);

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Type text into the reflection field.
        final textField = find.byType(TextField);
        await tester.ensureVisible(textField);
        await tester.enterText(textField, 'Today was productive');

        final submitBtn = find.text(
          messages.dailyOsNextShutdownReflectionSave,
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await _settle(tester);

        // The thanks text now appears.
        expect(
          find.text(messages.dailyOsNextShutdownReflectionThanks),
          findsOneWidget,
        );
        // The form is replaced.
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'narrow layout renders sections stacked vertically',
      (tester) async {
        tester.view
          ..physicalSize = const Size(600, 1200)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final agent = _fastAgent();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dayAgentProvider.overrideWithValue(agent)],
            child: makeTestableWidget2(
              ShutdownPage(forDate: DateTime(2026, 5, 25)),
              mediaQueryData: const MediaQueryData(size: Size(600, 1200)),
            ),
          ),
        );
        await _settle(tester);

        // Both the completed item and metrics should still render in narrow mode.
        expect(
          find.text('Deck review — Q2 leadership update'),
          findsOneWidget,
        );
        expect(find.text('Finish the Onboarding doc'), findsOneWidget);
      },
    );
  });

  group('ShutdownPage tomorrow note card', () {
    Future<void> pumpWithNote(WidgetTester tester, TomorrowNote note) async {
      _setView(tester);

      await tester.pumpWidget(
        _wrap(
          ShutdownPage(forDate: DateTime(2026, 5, 25)),
          overrides: [
            dayAgentProvider.overrideWithValue(_TomorrowNoteAgent(note)),
          ],
        ),
      );
      await _settle(tester);
    }

    testWidgets('renders the overline title and the generated body', (
      tester,
    ) async {
      await pumpWithNote(
        tester,
        const TomorrowNote(body: 'Pack slides for the standup.'),
      );

      final context = tester.element(find.byType(ShutdownPage));
      expect(
        find.text(context.messages.dailyOsNextShutdownTomorrowOverline),
        findsOneWidget,
      );
      expect(find.text('Pack slides for the standup.'), findsOneWidget);
    });

    testWidgets('an empty note body still renders the titled card', (
      tester,
    ) async {
      await pumpWithNote(tester, const TomorrowNote(body: ''));

      // An empty body renders as an empty Text under the overline title
      // without erroring.
      final context = tester.element(find.byType(ShutdownPage));
      expect(
        find.text(context.messages.dailyOsNextShutdownTomorrowOverline),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
