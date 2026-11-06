import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_make_her_yours_step.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Her ticker never settles, so these tests pump a fixed run of frames.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

DesignSystemChip _chip(WidgetTester tester, String label) =>
    tester.widget<DesignSystemChip>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(DesignSystemChip),
      ),
    );

void main() {
  // Lotti's outfits: the ones the step offers for the default character.
  final companionOutfits = CompanionLook.of(
    const CompanionCustomization().character,
  );
  late AppLocalizations m;

  setUpAll(registerAllFallbackValues);
  setUp(() async {
    m = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('OnboardingMakeHerYoursView', () {
    late List<Object?> picked;
    late List<String> pressed;

    setUp(() {
      picked = [];
      pressed = [];
    });

    Future<void> pumpView(
      WidgetTester tester, {
      CompanionCustomization custom = const CompanionCustomization(),
    }) async {
      setTestSurfaceSize(tester, const Size(480, 1400));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: OnboardingMakeHerYoursView(
              title: 'Make me yours',
              companion: const ColoredBox(
                key: ValueKey('her'),
                color: Color(0xFF000000),
              ),
              line: 'Pick how I look.',
              custom: custom,
              onOutfit: picked.add,
              onSkinTone: picked.add,
              onHairStyle: picked.add,
              onHairColour: picked.add,
              onContinue: () => pressed.add('continue'),
              onSkip: () => pressed.add('skip'),
              onBack: () => pressed.add('back'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('she stands full length left of her bubble, under the title', (
      tester,
    ) async {
      await pumpView(tester);

      final her = find.byKey(const ValueKey('her'));
      expect(tester.getSize(her).height, ControlSizes.companionCard);
      expect(
        tester.getSize(her).width / tester.getSize(her).height,
        closeTo(CompanionFraming.full.aspectRatio, 0.01),
      );
      final bubble = tester.widget<OnboardingSpeechBubble>(
        find.byType(OnboardingSpeechBubble),
      );
      expect(bubble.text, 'Pick how I look.');
      expect(bubble.tail, OnboardingBubbleTail.left);
      expect(
        tester.getCenter(her).dx,
        lessThan(tester.getCenter(find.text('Pick how I look.')).dx),
      );
      expect(
        tester.getBottomLeft(find.text('Make me yours')).dy,
        lessThanOrEqualTo(tester.getTopLeft(her).dy),
      );
    });

    testWidgets('one section per part of her look, each named', (
      tester,
    ) async {
      await pumpView(tester);

      for (final label in [
        m.companionSettingsOutfitLabel,
        m.companionSettingsSkinToneLabel,
        m.companionSettingsHairStyleLabel,
        m.companionSettingsHairColourLabel,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final outfit in companionOutfits) {
        expect(find.text(outfitName(m, outfit)), findsOneWidget);
      }
      for (final style in CompanionHairStyle.values) {
        expect(find.text(hairStyleName(m, style)), findsOneWidget);
      }
      for (final tone in CompanionSkinTone.values) {
        expect(
          find.bySemanticsLabel(m.companionSettingsSkinTone(tone.index + 1)),
          findsOneWidget,
        );
      }
      for (final colour in CompanionHairColour.values) {
        expect(
          find.byKey(ValueKey('companionSwatch-$colour')),
          findsOneWidget,
        );
      }
    });

    testWidgets('marks what she wears now: "Surprise me" with no outfit '
        'picked, and her hair style', (tester) async {
      await pumpView(tester);

      expect(_chip(tester, m.companionSettingsOutfitSurprise).selected, isTrue);
      expect(
        _chip(tester, outfitName(m, companionOutfits.first)).selected,
        isFalse,
      );
      const custom = CompanionCustomization();
      expect(
        _chip(tester, hairStyleName(m, custom.hairStyle)).selected,
        isTrue,
      );
    });

    testWidgets("offers the chosen character's outfits, not Lotti's", (
      tester,
    ) async {
      await pumpView(
        tester,
        custom: const CompanionCustomization(
          character: CompanionSpecies.grandpa,
        ),
      );

      final his = CompanionLook.of(CompanionSpecies.grandpa);
      expect(his, isNotEmpty);
      for (final outfit in his) {
        expect(find.text(outfitName(m, outfit)), findsOneWidget);
      }
      // Every character's first outfit is named "Everyday".
      for (final outfit in companionOutfits.skip(1)) {
        expect(find.text(outfitName(m, outfit)), findsNothing);
      }
    });

    testWidgets('a picked outfit is the one marked', (tester) async {
      final outfit = companionOutfits.last;
      await pumpView(
        tester,
        custom: const CompanionCustomization().copyWith(
          outfitId: () => outfit.id,
        ),
      );

      expect(_chip(tester, outfitName(m, outfit)).selected, isTrue);
      expect(
        _chip(tester, m.companionSettingsOutfitSurprise).selected,
        isFalse,
      );
    });

    testWidgets('each choice reports what was picked', (tester) async {
      await pumpView(tester);
      final outfit = companionOutfits.last;

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
      }

      await tap(find.text(outfitName(m, outfit)));
      await tap(find.text(m.companionSettingsOutfitSurprise));
      await tap(
        find.byKey(
          ValueKey('companionSwatch-${CompanionSkinTone.values.last}'),
        ),
      );
      await tap(find.text(hairStyleName(m, CompanionHairStyle.afro)));
      await tap(
        find.byKey(
          ValueKey('companionSwatch-${CompanionHairColour.values.last}'),
        ),
      );

      expect(picked, [
        outfit.id,
        null,
        CompanionSkinTone.values.last,
        CompanionHairStyle.afro,
        CompanionHairColour.values.last,
      ]);
    });

    testWidgets('"Looks good", "Skip for now" and back each do their own '
        'thing', (tester) async {
      await pumpView(tester);

      for (final label in [
        m.onboardingMakeHerYoursContinue,
        m.onboardingMakeHerYoursSkip,
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.ensureVisible(find.byIcon(LottiIcons.back));
      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pump();

      expect(pressed, ['continue', 'skip', 'back']);
    });
  });

  group('OnboardingMakeHerYoursStep', () {
    late SettingsDb db;
    late MockOutboxService outbox;
    late int customized;

    setUp(() {
      db = SettingsDb(inMemoryDatabase: true);
      outbox = MockOutboxService();
      when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
      customized = 0;
    });
    tearDown(() => db.close());

    Future<ProviderContainer> pumpStep(WidgetTester tester) async {
      setTestSurfaceSize(tester, const Size(480, 1400));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: OnboardingMakeHerYoursStep(
              onContinue: () {},
              onSkip: () {},
              onBack: () {},
              onCustomized: () => customized++,
            ),
          ),
          overrides: [
            settingsDbProvider.overrideWithValue(db),
            outboxServiceProvider.overrideWithValue(outbox),
            companionOutfitProvider.overrideWithBuild(
              (ref, notifier) => CompanionLook.grandma,
            ),
            ttsPlaybackControllerProvider.overrideWith(
              () => TtsPlaybackController(logger: MockDomainLogger()),
            ),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) => Completer<MouthTrack>().future,
            ),
          ],
        ),
      );
      await _frames(tester);
      return ProviderScope.containerOf(
        tester.element(find.byType(OnboardingMakeHerYoursView)),
      );
    }

    testWidgets('she is there to be dressed, saying where it all lives later', (
      tester,
    ) async {
      await pumpStep(tester);

      final her = tester.widget<OnboardingCompanion>(
        find.byType(OnboardingCompanion),
      );
      expect(her.beat, OnboardingCompanionBeat.dressUp);
      expect(her.line, m.onboardingMakeHerYoursLine);
      expect(find.text(m.onboardingMakeHerYoursTitle), findsOneWidget);
    });

    testWidgets('a pick is saved at once and shown as picked', (tester) async {
      final container = await pumpStep(tester);

      final afro = find.text(hairStyleName(m, CompanionHairStyle.afro));
      await tester.ensureVisible(afro);
      await tester.tap(afro);
      await _frames(tester);
      final tone = find.byKey(
        ValueKey('companionSwatch-${CompanionSkinTone.values.last}'),
      );
      await tester.ensureVisible(tone);
      await tester.tap(tone);
      await _frames(tester);

      final custom = container.read(companionCustomizationProvider);
      expect(custom.hairStyle, CompanionHairStyle.afro);
      expect(custom.skinTone, CompanionSkinTone.values.last);
      expect(
        _chip(tester, hairStyleName(m, CompanionHairStyle.afro)).selected,
        isTrue,
      );
    });

    testWidgets('an outfit pick and "Surprise me" set and clear the outfit', (
      tester,
    ) async {
      final container = await pumpStep(tester);
      final outfit = companionOutfits.last;

      await tester.tap(find.text(outfitName(m, outfit)));
      await _frames(tester);
      expect(
        container.read(companionCustomizationProvider).outfitId,
        outfit.id,
      );

      await tester.tap(find.text(m.companionSettingsOutfitSurprise));
      await _frames(tester);
      expect(container.read(companionCustomizationProvider).outfitId, isNull);
    });

    testWidgets('the first pick reports a customisation, later ones do not', (
      tester,
    ) async {
      await pumpStep(tester);
      expect(customized, 0);

      final colour = find.byKey(
        ValueKey('companionSwatch-${CompanionHairColour.values.last}'),
      );
      await tester.ensureVisible(colour);
      await tester.tap(colour);
      await _frames(tester);
      final style = find.text(hairStyleName(m, CompanionHairStyle.bob));
      await tester.ensureVisible(style);
      await tester.tap(style);
      await _frames(tester);

      expect(customized, 1);
    });
  });
}
