import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Applies the standard tall-desktop view geometry every test needs and
/// registers its reset.
void _setView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1280, 1100)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1280, 1100)),
    ),
  );
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
  clock: () => DateTime(2026, 5, 25, 9),
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
        clock: () => DateTime(2026, 5, 25, 9),
      );

  final TomorrowNote note;

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => note;
}

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
      await tester.pump(const Duration(milliseconds: 200));

      // Mock returns 2 completed items + 2 carryover items.
      expect(find.text('Deck review — Q2 leadership update'), findsOneWidget);
      expect(find.text('Morning run · 5km'), findsOneWidget);
      expect(find.text('Finish the Onboarding doc'), findsOneWidget);
      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      // For-tomorrow note body — the mock generates a paragraph.
      expect(find.textContaining('Onboarding doc'), findsWidgets);
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
                contextSwitchesWeekAvg: 0,
                energyScore: 0,
                energyDeltaVsWeek: 0,
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
      await tester.pump(const Duration(milliseconds: 200));

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
      await tester.pump(const Duration(milliseconds: 200));

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
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ShutdownPage)).messages;
        final control = finderFor(messages);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(ShutdownPage), findsNothing);
      }
    });

    testWidgets(
      'tapping a carryover suggested chip collapses the row to a confirmation',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Mock surfaces "→ tomorrow morning" / "→ tomorrow afternoon"
        // as primary chips.
        final morning = find.text('→ tomorrow morning');
        expect(morning, findsOneWidget);

        await tester.ensureVisible(morning);
        await tester.tap(morning);
        await tester.pump(const Duration(milliseconds: 200));

        // After the decision the label reappears inside the
        // confirmation pill; the original button is gone.
        expect(find.text('→ tomorrow morning'), findsOneWidget);
        // The Pick-a-date secondary button still exists for the
        // second carryover row that wasn't decided.
        expect(find.text('Pick a date'), findsOneWidget);
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
        await tester.pump(const Duration(milliseconds: 200));

        // Tap the leading back icon (not the footer TextButton).
        final backIcon = find.widgetWithIcon(
          IconButton,
          Icons.arrow_back_rounded,
        );
        expect(backIcon, findsOneWidget);
        await tester.tap(backIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped, isTrue);
        expect(find.byType(ShutdownPage), findsNothing);
      },
    );

    testWidgets(
      'tapping Pick-a-date shows Scheduled decision pill; '
      'tapping Drop shows Dropped decision pill',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Both carryover rows show "Pick a date" and "Drop".
        final pickDate = find.text(
          messages.dailyOsNextShutdownCarryoverPickDate,
        );
        expect(pickDate, findsNWidgets(2));

        // Tap "Pick a date" on the first carryover row.
        await tester.ensureVisible(pickDate.first);
        await tester.tap(pickDate.first);
        await tester.pump(const Duration(milliseconds: 200));

        // The first row now shows the "Scheduled" pill.
        expect(
          find.text(messages.dailyOsNextShutdownCarryoverScheduled),
          findsOneWidget,
        );
        // The second row still offers "Drop".
        final dropButton = find.text(messages.dailyOsNextShutdownCarryoverDrop);
        expect(dropButton, findsOneWidget);

        // Tap "Drop" on the remaining carryover row.
        await tester.ensureVisible(dropButton);
        await tester.tap(dropButton);
        await tester.pump(const Duration(milliseconds: 200));

        // The second row now shows the "Dropped" pill.
        expect(
          find.text(messages.dailyOsNextShutdownCarryoverDropped),
          findsOneWidget,
        );
        // No more undecided action buttons visible.
        expect(
          find.text(messages.dailyOsNextShutdownCarryoverPickDate),
          findsNothing,
        );
        expect(
          find.text(messages.dailyOsNextShutdownCarryoverDrop),
          findsNothing,
        );
      },
    );

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
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Leave the text field empty and tap the submit/skip button.
        final skipBtn = find.text(messages.dailyOsNextShutdownReflectionSubmit);
        await tester.ensureVisible(skipBtn);
        await tester.tap(skipBtn);
        await tester.pump(const Duration(milliseconds: 200));

        // The form should still be visible — no thanks text shown.
        expect(skipBtn, findsOneWidget);
        expect(
          find.text(messages.dailyOsNextShutdownReflectionThanks),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping Speak with text calls submitReflection and shows thanks',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Type text into the reflection field.
        final textField = find.byType(TextField);
        await tester.ensureVisible(textField);
        await tester.enterText(textField, 'Great focus today');

        // Tap the Speak button (voice source).
        final speakBtn = find.text(messages.dailyOsNextShutdownReflectionSpeak);
        await tester.ensureVisible(speakBtn);
        await tester.tap(speakBtn);
        await tester.pump(const Duration(milliseconds: 200));

        // After a successful submit, the thanks confirmation appears.
        expect(
          find.text(messages.dailyOsNextShutdownReflectionThanks),
          findsOneWidget,
        );
        // The form (text field + buttons) is gone.
        expect(textField, findsNothing);
      },
    );

    testWidgets(
      'tapping Submit/Skip with text calls submitReflection and shows thanks',
      (tester) async {
        _setView(tester);

        final agent = _fastAgent();
        await tester.pumpWidget(
          _wrap(
            ShutdownPage(forDate: DateTime(2026, 5, 25)),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final messages = tester.element(find.byType(ShutdownPage)).messages;

        // Type text into the reflection field.
        final textField = find.byType(TextField);
        await tester.ensureVisible(textField);
        await tester.enterText(textField, 'Today was productive');

        // Tap the text Submit/Skip button (typed source).
        final submitBtn = find.text(
          messages.dailyOsNextShutdownReflectionSubmit,
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pump(const Duration(milliseconds: 200));

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
        await tester.pump(const Duration(milliseconds: 200));

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
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('renders the overline title and the generated body', (
      tester,
    ) async {
      await pumpWithNote(
        tester,
        const TomorrowNote(body: 'Pack slides for the standup.', maturity: 2),
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
      await pumpWithNote(tester, const TomorrowNote(body: '', maturity: 0));

      // _TomorrowNoteCard has no dedicated empty-state branch (and no
      // maturity indicator); an empty body renders as an empty Text under
      // the overline title without erroring.
      final context = tester.element(find.byType(ShutdownPage));
      expect(
        find.text(context.messages.dailyOsNextShutdownTomorrowOverline),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
