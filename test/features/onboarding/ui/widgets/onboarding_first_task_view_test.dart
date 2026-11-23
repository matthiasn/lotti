import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:material_ui/material_ui.dart';

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
    List<OnboardingCaptureCategory> categories = oneCategory,
    String selectedCategoryId = 'c1',
    bool reduceMotion = true,
    String createdTaskTitle = '',
    Widget? companion,
    VoidCallback? onClose,
    VoidCallback? onBack,
    VoidCallback? onStartOver,
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
              accent: accent,
              title: 'Create your first task',
              guidance: 'Tap to talk and say what needs doing.',
              suggestionsLabel: 'Or start with one of these:',
              suggestions: suggestions,
              listeningCaption: 'Tap when done',
              thinkingHeadline: 'Building your task',
              thinkingReassurance: 'You can edit everything next',
              ratherTypeLabel: 'Rather type?',
              recordSemanticLabel: 'Record',
              recordLabel: 'Tap to talk',
              stopLabel: 'Done',
              openTaskLabel: 'Open task',
              categoryPrompt: 'Where should this land?',
              createdHeadline: 'Your first task is ready',
              createdTaskTitle: createdTaskTitle,
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onSelectCategory: categoryPicks.add,
              onRecordTap: () => recordTaps++,
              onSuggestionTap: suggestionTaps.add,
              onRatherType: () => ratherTypeTaps++,
              onOpenTask: () => openTaskTaps++,
              companion: companion,
              onClose: onClose,
              onBack: onBack,
              onStartOver: onStartOver,
              startOverLabel: 'Start over',
              createdCaption: 'Your task',
              landedIn: 'Work',
              createdText: 'It is in Work.',
              transcript: 'call the dentist and book the car service',
              amplitudes: const [0.2, 0.6, 0.4, 0.8, 0.3],
              dbfs: -20,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(390, 1400),
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

      await tester.ensureVisible(find.text('Rather type?'));
      await tester.tap(find.text('Rather type?'), warnIfMissed: false);
      expect(ratherTypeTaps, 1);
    });

    testWidgets('the main button opens the mic, and no recorder stands in '
        'the tray until it has', (tester) async {
      await pumpView(tester, OnboardingFirstTaskPhase.prompt);

      expect(find.byType(VoiceOrbZone), findsNothing);
      final stage = tester.widget<OnboardingStage>(
        find.byType(OnboardingStage),
      );
      expect(stage.primary?.label, 'Tap to talk');
      expect(stage.primary?.icon, LottiIcons.mic);

      await tester.ensureVisible(find.text('Tap to talk'));
      await tester.tap(find.text('Tap to talk'), warnIfMissed: false);
      expect(recordTaps, 1);
    });
  });

  group('recorder', () {
    testWidgets('listening, the tray holds the tappable orb zone', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.listening);

      expect(find.byType(VoiceOrbZone), findsOneWidget);

      await tester.tap(find.byType(VoiceButton), warnIfMissed: false);
      expect(recordTaps, 1);
    });
  });

  group('listening frame', () {
    testWidgets('shows the caption and hides guidance + suggestions', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.listening);

      expect(find.text('Tap when done'), findsOneWidget);
      expect(find.text('Tap to talk and say what needs doing.'), findsNothing);
      expect(find.text('Or start with one of these:'), findsNothing);
      // Typing instead would throw away what is being said: not offered
      // while the mic is open.
      expect(find.text('Rather type?'), findsNothing);
    });

    testWidgets('light themed orb keeps a defined center surface', (
      tester,
    ) async {
      await pumpView(tester, OnboardingFirstTaskPhase.listening);

      final core = find.byKey(VoiceButton.coreButtonKey);
      final ink = tester.widget<Ink>(
        find.ancestor(of: core, matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(
        decoration.color,
        tester.element(core).designTokens.colors.background.level02,
      );
    });

    testWidgets('the headline and the live caption lead, and the main '
        'button ends the recording', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.listening,
        categories: twoCategories,
      );

      final stage = tester.widget<OnboardingStage>(
        find.byType(OnboardingStage),
      );
      expect(stage.title, 'Create your first task');
      expect(stage.text, 'Tap when done');
      expect(stage.secondary, isNull);
      expect(stage.primary?.label, 'Done');
      // A check: Done keeps what was said; the orb is the one stop shape.
      expect(stage.primary?.icon, LottiIcons.confirm);
      // The caption is over the recorder, the main button under it.
      expect(
        tester.getBottomLeft(find.text('Tap when done')).dy,
        lessThan(tester.getTopLeft(find.byType(VoiceOrbZone)).dy),
      );
      expect(
        tester.getBottomLeft(find.byType(VoiceOrbZone)).dy,
        lessThan(tester.getTopLeft(find.text('Done')).dy),
      );

      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'), warnIfMissed: false);
      expect(recordTaps, 1);
    });
  });

  testWidgets('while listening the link starts over, dropping what was '
      'said; at the prompt it is typing instead', (tester) async {
    var startedOver = 0;
    await pumpView(
      tester,
      OnboardingFirstTaskPhase.listening,
      onStartOver: () => startedOver++,
    );
    await tester.ensureVisible(find.text('Start over'));
    await tester.tap(find.text('Start over'), warnIfMissed: false);
    expect(startedOver, 1);

    await pumpView(
      tester,
      OnboardingFirstTaskPhase.prompt,
      onStartOver: () => startedOver++,
    );
    expect(find.text('Start over'), findsNothing);
    expect(find.text('Rather type?'), findsOneWidget);
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
      // The recorder is gone while thinking.
      expect(find.byType(VoiceOrbZone), findsNothing);
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
      'shows the task as a preview card, her bubble saying where it is, no '
      'checklist, and the main button the way to it',
      (tester) async {
        await pumpView(
          tester,
          OnboardingFirstTaskPhase.created,
          createdTaskTitle: title,
        );

        expect(find.text('Your first task is ready'), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        final stage = tester.widget<OnboardingStage>(
          find.byType(OnboardingStage),
        );
        expect(stage.text, 'It is in Work.');
        // Under a caption, like every step's content; its area under its
        // title, and a check that says it is done.
        expect(stage.caption, 'Your task');
        expect(
          tester.getBottomLeft(find.text(title)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Work')).dy),
        );
        expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
        // No checklist preview on the card — those items surface as
        // confirmable proposals once the user opens the task.
        expect(find.byIcon(LottiIcons.radioUnselected), findsNothing);
        // The composing/thinking furniture is gone — the card owns the tray.
        expect(find.text('Rather type?'), findsNothing);
        expect(find.byType(VoiceOrbZone), findsNothing);
        // One way on: the card itself is not a second button.
        await tester.tap(find.text(title), warnIfMissed: false);
        expect(openTaskTaps, 0);
      },
    );

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

    testWidgets('shows all areas at the prompt', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.prompt,
        categories: twoCategories,
      );

      expect(find.text('Where should this land?'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('is hidden once the mic is open', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.listening,
        categories: twoCategories,
      );

      expect(find.text('Where should this land?'), findsNothing);
    });

    testWidgets('tapping an area reports its id', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.prompt,
        categories: twoCategories,
      );

      await tester.tap(find.text('Family'), warnIfMissed: false);
      expect(categoryPicks, ['c2']);
    });

    testWidgets('an area activates via keyboard', (tester) async {
      await pumpView(
        tester,
        OnboardingFirstTaskPhase.prompt,
        categories: twoCategories,
      );

      final family = find.text('Family');
      final focus = Focus.of(tester.element(family))..requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

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

  testWidgets('the companion stands on the stage, the headline and the '
      'guidance in the bubble under her', (tester) async {
    await pumpView(
      tester,
      OnboardingFirstTaskPhase.prompt,
      companion: const ColoredBox(key: ValueKey('her'), color: Colors.red),
    );

    final her = tester.getRect(find.byKey(const ValueKey('her')));
    final bubble = find.byType(OnboardingSpeechBubble);
    expect(her.bottom, lessThanOrEqualTo(tester.getTopLeft(bubble).dy));
    expect(
      tester.widget<OnboardingSpeechBubble>(bubble).title,
      'Create your first task',
    );
    expect(
      tester.widget<OnboardingSpeechBubble>(bubble).text,
      'Tap to talk and say what needs doing.',
    );
  });

  testWidgets('the progress moves with the frame, the close button leaves '
      'on every frame, and back to the areas is only offered at the prompt', (
    tester,
  ) async {
    var back = 0;
    var left = 0;
    Future<OnboardingStage> stageFor(OnboardingFirstTaskPhase phase) async {
      await pumpView(
        tester,
        phase,
        onClose: () => left++,
        onBack: () => back++,
      );
      return tester.widget<OnboardingStage>(find.byType(OnboardingStage));
    }

    final prompt = await stageFor(OnboardingFirstTaskPhase.prompt);
    expect(prompt.progress, const OnboardingProgress(done: 2, current: 0.25));
    await tester.tap(find.byIcon(LottiIcons.close));
    expect(left, 1);
    await tester.tap(find.byIcon(LottiIcons.back));
    expect(back, 1);

    final listening = await stageFor(OnboardingFirstTaskPhase.listening);
    expect(listening.progress, const OnboardingProgress(done: 2, current: 0.5));
    expect(listening.onClose, isNotNull);
    // The arrow stays in the bar, disabled, once something is being said.
    expect(listening.onBack, isNull);
    expect(listening.showBack, isTrue);

    final thinking = await stageFor(OnboardingFirstTaskPhase.thinking);
    expect(thinking.progress, const OnboardingProgress(done: 2, current: 0.75));
    // Nothing to press while the words are being structured.
    expect(thinking.primary, isNull);

    final created = await stageFor(OnboardingFirstTaskPhase.created);
    expect(created.progress, const OnboardingProgress(done: 3));
    // A way out stays once the task has landed, beside Open task.
    expect(created.onClose, isNotNull);
    expect(created.primary?.label, 'Open task');
    await tester.ensureVisible(find.text('Open task'));
    await tester.tap(find.text('Open task'), warnIfMissed: false);
    expect(openTaskTaps, 1);
  });

  testWidgets('without a companion, the headline leads', (tester) async {
    await pumpView(tester, OnboardingFirstTaskPhase.prompt);

    expect(find.byKey(const ValueKey('her')), findsNothing);
    expect(find.byType(OnboardingSpeechBubble), findsNothing);
    expect(find.text('Tap to talk and say what needs doing.'), findsOneWidget);
  });

  testWidgets('with her, the headline and the guidance are her bubble', (
    tester,
  ) async {
    await pumpView(
      tester,
      OnboardingFirstTaskPhase.prompt,
      companion: const ColoredBox(key: ValueKey('her'), color: Colors.red),
    );

    final bubble = tester.widget<OnboardingSpeechBubble>(
      find.byType(OnboardingSpeechBubble),
    );
    expect(bubble.title, 'Create your first task');
    expect(bubble.text, 'Tap to talk and say what needs doing.');
    // Said once, in the bubble.
    expect(find.text('Tap to talk and say what needs doing.'), findsOneWidget);
  });

  testWidgets('while she thinks her bubble says nothing is final yet', (
    tester,
  ) async {
    await pumpView(
      tester,
      OnboardingFirstTaskPhase.thinking,
      companion: const ColoredBox(key: ValueKey('her'), color: Colors.red),
    );

    final bubble = tester.widget<OnboardingSpeechBubble>(
      find.byType(OnboardingSpeechBubble),
    );
    expect(bubble.title, 'Building your task');
    expect(bubble.text, 'You can edit everything next');
    // Said once: not again under the pulse.
    expect(find.text('You can edit everything next'), findsOneWidget);
  });
}
