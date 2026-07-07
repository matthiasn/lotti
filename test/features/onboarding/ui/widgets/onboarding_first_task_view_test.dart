import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);
  const suggestions = ['Plan my week', 'Book the dentist', 'Prep the meeting'];
  const oneCategory = [OnboardingCaptureCategory(id: 'c1', label: 'Work')];
  const twoCategories = [
    OnboardingCaptureCategory(id: 'c1', label: 'Work'),
    OnboardingCaptureCategory(id: 'c2', label: 'Family'),
  ];

  var recordTaps = 0;
  var ratherTypeTaps = 0;
  var openTaskTaps = 0;
  var suggestionTaps = <String>[];
  var categoryPicks = <String>[];

  setUp(() {
    recordTaps = 0;
    ratherTypeTaps = 0;
    openTaskTaps = 0;
    suggestionTaps = <String>[];
    categoryPicks = <String>[];
  });

  Future<void> pumpView(
    WidgetTester tester,
    OnboardingFirstTaskPhase phase, {
    RecordingStyle style = RecordingStyle.modern,
    List<OnboardingCaptureCategory> categories = oneCategory,
    String selectedCategoryId = 'c1',
    bool reduceMotion = true,
    String createdTaskTitle = '',
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        // The real flow hosts this inside the modal's Scaffold; mirror that so
        // the suggestion chips' InkWells find their Material ancestor.
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 390,
            child: OnboardingFirstTaskView(
              phase: phase,
              style: style,
              accent: accent,
              colorScheme: const ColorScheme.dark(),
              title: 'Create your first task',
              guidance: 'Tap to talk and say what needs doing.',
              suggestionsLabel: 'Or start with one of these:',
              suggestions: suggestions,
              listeningCaption: 'Tap when done',
              thinkingHeadline: 'Building your task',
              thinkingReassurance: 'You can edit everything next',
              ratherTypeLabel: 'Rather type?',
              recordSemanticLabel: 'Record',
              categoryPrompt: 'Where should this land?',
              createdHeadline: 'Your first task is ready',
              createdHint: 'Tap your task to open it',
              createdTaskTitle: createdTaskTitle,
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onSelectCategory: categoryPicks.add,
              onRecordTap: () => recordTaps++,
              onSuggestionTap: suggestionTaps.add,
              onRatherType: () => ratherTypeTaps++,
              onOpenTask: () => openTaskTaps++,
              transcript: 'call the dentist and book the car service',
              amplitudes: const [0.2, 0.6, 0.4, 0.8, 0.3],
              dbfs: -20,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduceMotion,
        ),
      ),
    );
    await tester.pump();
  }

  group('prompt frame', () {
    testWidgets('shows title, guidance, suggestions and the escape hatch', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      expect(find.text('Create your first task'), findsOneWidget);
      expect(
        find.text('Tap to talk and say what needs doing.'),
        findsOneWidget,
      );
      expect(find.text('Or start with one of these:'), findsOneWidget);
      for (final suggestion in suggestions) {
        expect(find.text(suggestion), findsOneWidget);
      }
      expect(find.text('Rather type?'), findsOneWidget);
    });

    testWidgets('tapping a suggestion reports its text', (tester) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      await tester.tap(find.text('Book the dentist'), warnIfMissed: false);
      expect(suggestionTaps, ['Book the dentist']);
    });

    testWidgets('Rather type? invokes its callback', (tester) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      // Invoke the handler directly: the idle orb's shader overflow box can
      // cover the lower region in the test surface, so a hit-test tap is
      // unreliable — we're verifying the callback is wired, not geometry.
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Rather type?'))
          .onPressed!();
      expect(ratherTypeTaps, 1);
    });
  });

  group('recording style', () {
    testWidgets('modern renders the tappable orb zone', (tester) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      expect(find.byType(VoiceOrbZone), findsOneWidget);
      expect(find.byType(AnalogVuMeter), findsNothing);

      await tester.tap(find.byType(VoiceButton), warnIfMissed: false);
      expect(recordTaps, 1);
    });

    testWidgets('analogue renders the tappable VU meter pair', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.prompt,
        style: RecordingStyle.analogue,
      );

      expect(find.byType(AnalogVuMeter), findsOneWidget);
      expect(find.byType(VoiceOrbZone), findsNothing);

      await tester.tap(find.byType(AnalogVuMeter), warnIfMissed: false);
      expect(recordTaps, 1);
    });

    testWidgets(
      'the analogue meter also rides the live level while listening',
      (
        tester,
      ) async {
        await pumpView(
          tester,
          OnboardingFirstTaskPhase.listening,
          style: RecordingStyle.analogue,
        );

        // The meter receives the injected live dBFS (VU = dBFS + 18, clamped).
        final meter = tester.widget<AnalogVuMeter>(find.byType(AnalogVuMeter));
        expect(meter.dBFS, -20);
        expect(meter.vu, -2);
      },
    );
  });

  group('listening frame', () {
    testWidgets('shows the caption and hides guidance + suggestions', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.listening);

      expect(find.text('Tap when done'), findsOneWidget);
      expect(find.text('Tap to talk and say what needs doing.'), findsNothing);
      expect(find.text('Or start with one of these:'), findsNothing);
      // Still composing, so the escape hatch remains.
      expect(find.text('Rather type?'), findsOneWidget);
    });
  });

  group('thinking frame', () {
    testWidgets('echoes the transcript with the pulse and reassurance', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.thinking);

      expect(find.text('Building your task'), findsOneWidget);
      expect(
        find.text('"call the dentist and book the car service"'),
        findsOneWidget,
      );
      expect(find.text('You can edit everything next'), findsOneWidget);
      // No escape hatch or suggestions once we're past composing — the next
      // frame is the created beat, not more input.
      expect(find.text('Rather type?'), findsNothing);
      expect(find.text('Or start with one of these:'), findsNothing);
      // Neither recording visual renders while thinking.
      expect(find.byType(VoiceOrbZone), findsNothing);
      expect(find.byType(AnalogVuMeter), findsNothing);
    });

    testWidgets('the pulse loops when motion is enabled', (tester) async {
      // Motion ON → the teal "processing" pulse repeats (the non-reduced-motion
      // branch). Bounded pumps; never pumpAndSettle a repeating animation.
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.thinking,
        reduceMotion: false,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Building your task'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Unmount to stop the perpetual pulse so the test tears down cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('created frame', () {
    const title = 'Plan my week';

    testWidgets(
      'shows a title-only card with the open hint (checklist is not '
      'previewed — it lands as proposals on the task page)',
      (tester) async {
        await pumpView(
          tester,
          OnboardingFirstTaskPhase.created,
          createdTaskTitle: title,
        );

        expect(find.text('Your first task is ready'), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Tap your task to open it'), findsOneWidget);
        // No checklist preview on the card — those items surface as confirmable
        // proposals once the user opens the task.
        expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
        // The composing/thinking furniture is gone — the card owns the panel.
        expect(find.text('Rather type?'), findsNothing);
        expect(find.byType(VoiceOrbZone), findsNothing);
        expect(find.byType(AnalogVuMeter), findsNothing);
      },
    );

    testWidgets('tapping the card fires onOpenTask', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.created,
        createdTaskTitle: title,
      );

      await tester.tap(find.text(title), warnIfMissed: false);
      expect(openTaskTaps, 1);
    });

    testWidgets('the invite glow loops when motion is enabled', (
      tester,
    ) async {
      // Motion ON → entrance settle + breathing glow repeat. Bounded pumps;
      // never pumpAndSettle a repeating animation.
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.created,
        reduceMotion: false,
        createdTaskTitle: title,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Unmount to stop the perpetual glow so the test tears down cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('destination picker', () {
    testWidgets('is hidden with a single created area', (tester) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      expect(find.text('Where should this land?'), findsNothing);
    });

    for (final phase in [
      OnboardingFirstTaskPhase.prompt,
      OnboardingFirstTaskPhase.listening,
    ]) {
      testWidgets('shows all areas while composing (${phase.name})', (
        tester,
      ) async {
        await pumpView(tester, phase, categories: twoCategories);

        expect(find.text('Where should this land?'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Family'), findsOneWidget);
      });
    }

    testWidgets('tapping an area reports its id', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.prompt,
        categories: twoCategories,
      );

      await tester.tap(find.text('Family'), warnIfMissed: false);
      expect(categoryPicks, ['c2']);
    });

    testWidgets('is hidden once structuring starts', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.thinking,
        categories: twoCategories,
      );

      expect(find.text('Where should this land?'), findsNothing);
    });
  });
}
