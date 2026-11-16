import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_flourish.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voices_section.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import 'companion_settings_harness.dart';

void main() {
  late SettingsDb db;
  late MockOutboxService outbox;

  setUpAll(registerAllFallbackValues);
  setUp(() {
    db = SettingsDb(inMemoryDatabase: true);
    outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  Future<void> pumpBody(
    WidgetTester tester, {
    CompanionCustomization customization = const CompanionCustomization(),
    bool surprise = false,
    bool readAloud = false,
    CompanionSettingsTab tab = CompanionSettingsTab.look,
  }) => pumpCompanionSettings(
    tester,
    db: db,
    outbox: outbox,
    customization: customization,
    readAloud: readAloud,
    surprise: surprise,
    tab: tab,
  );

  TtsSettings voiceSettings(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(CompanionSettingsBody)),
  ).read(ttsSettingsControllerProvider);

  CompanionCustomization chosen(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(CompanionSettingsBody)),
      ).read(companionCustomizationProvider);

  List<CompanionView> previews(WidgetTester tester) =>
      tester.widgetList<CompanionView>(find.byType(CompanionView)).toList();

  testWidgets('the look tab dresses her, head to toe and as a portrait, in '
      'what is chosen, in three groups', (
    tester,
  ) async {
    await pumpBody(
      tester,
      customization: const CompanionCustomization(
        hairStyle: CompanionHairStyle.curls,
      ),
    );
    final views = previews(tester);
    expect(views.map((v) => v.framing), [
      CompanionFraming.full,
      CompanionFraming.bust,
    ]);
    for (final view in views) {
      expect(view.look.id, CompanionLook.grandmaGarden.id);
      expect(view.look.hairStyle, CompanionHairStyle.curls);
      expect(view.autoGestures, isFalse);
    }
    for (final title in [
      'Character',
      'Outfit',
      'Hair',
      'Hairstyle',
      'Hair color',
      'Skin and eyes',
      'Skin tone',
      'Eye color',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // What is not her look is on a tab of its own.
    expect(find.text('Sass'), findsNothing);
    expect(
      find.byKey(const ValueKey('companion-speaks-replies')),
      findsNothing,
    );
  });

  testWidgets('a skin tone swatch changes her skin, and says its name', (
    tester,
  ) async {
    await pumpBody(tester);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone1')),
      ),
      matchesSemantics(
        label: 'Skin tone 1',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone4')),
    );
    await pumpCompanionFrames(tester);

    expect(chosen(tester).skinTone, CompanionSkinTone.tone4);
    expect(
      previews(tester).first.look.palette.skin,
      CompanionSkinTone.tone4.skin,
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone4')),
      ),
      matchesSemantics(
        label: 'Skin tone 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('a screen reader can choose a swatch by its tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpBody(tester);

    tester.semantics.tap(find.semantics.byLabel('Skin tone 6'));
    await pumpCompanionFrames(tester);

    expect(chosen(tester).skinTone, CompanionSkinTone.tone6);
    semantics.dispose();
  });

  testWidgets('a hairstyle chip changes her hair', (tester) async {
    await pumpBody(tester);
    await tester.tap(find.text('Afro'));
    await pumpCompanionFrames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.afro);
    expect(previews(tester).last.look.hairStyle, CompanionHairStyle.afro);
  });

  testWidgets('a hair colour swatch changes her hair colour', (tester) async {
    await pumpBody(tester);
    await tester.tap(
      find.byKey(const ValueKey('companionSwatch-CompanionHairColour.pink')),
    );
    await pumpCompanionFrames(tester);
    expect(chosen(tester).hairColour, CompanionHairColour.pink);
    expect(
      previews(tester).first.look.palette.hair,
      CompanionHairColour.pink.hair,
    );
  });

  testWidgets('an outfit chip dresses her in it; "Surprise me" lets her pick', (
    tester,
  ) async {
    await pumpBody(tester);
    bool selected(String label) => tester
        .widget<DesignSystemChip>(
          find.widgetWithText(DesignSystemChip, label),
        )
        .selected;
    expect(selected('Surprise me'), isTrue);

    await tester.tap(find.text('Winter'));
    await pumpCompanionFrames(tester);
    expect(chosen(tester).outfitId, 'grandma_winter');
    expect(selected('Winter'), isTrue);
    expect(selected('Surprise me'), isFalse);

    await tester.tap(find.text('Surprise me'));
    await pumpCompanionFrames(tester);
    expect(chosen(tester).outfitId, isNull);
    expect(selected('Surprise me'), isTrue);
  });

  testWidgets('on "Surprise me" her preview keeps the outfit drawn for her '
      'settings while other choices change', (tester) async {
    await pumpBody(tester, surprise: true);
    final expected = CompanionLookRoll(
      customization: const CompanionCustomization(),
      picked: null,
      seed: 7,
    ).outfitFor(companionSettingsDressedFor).id;
    expect(previews(tester).map((v) => v.look.id), everyElement(expected));

    await tester.tap(find.text('Afro').last);
    await pumpCompanionFrames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.afro);
    expect(
      previews(tester).map((v) => v.look.hairStyle),
      everyElement(CompanionHairStyle.afro),
    );
    expect(previews(tester).map((v) => v.look.id), everyElement(expected));
  });

  testWidgets('every choice is stored as it is made, and sent to the other '
      'devices', (tester) async {
    await pumpBody(tester);
    await tester.tap(find.text('Locs').last);
    await pumpCompanionFrames(tester);
    final stored = await tester.runAsync(
      () => db.itemByKey(companionCustomizationKey),
    );
    expect(stored, contains('"hairStyle":"locs"'));
    final sent =
        verify(() => outbox.enqueueMessage(captureAny())).captured.single
            as SyncCompanionCustomization;
    expect(sent.customization, contains('"hairStyle":"locs"'));
  });

  testWidgets('a sass segment stores her sass, and she shows it', (
    tester,
  ) async {
    await pumpBody(tester, tab: CompanionSettingsTab.personality);
    expect(chosen(tester).sass, CompanionSass.cheeky);
    final full = previews(tester).first.controller!;

    await tester.tap(find.text('Sassy').last);
    await tester.pump(const Duration(milliseconds: 16));
    expect(chosen(tester).sass, CompanionSass.sassy);
    // How she takes a slip at full sass: hands on hips, over the glasses.
    expect(full.gesture, GestureName.handsOnHips);
    expect(full.flourishing, CompanionFlourish.overTheGlasses);

    await tester.tap(find.text('Warm').last);
    await tester.pump(const Duration(milliseconds: 16));
    expect(chosen(tester).sass, CompanionSass.warm);
    expect(full.gesture, GestureName.palmsDown);
    expect(full.flourishing, CompanionFlourish.headTilt);

    await pumpCompanionFrames(tester);
    final stored = await db.itemByKey(companionCustomizationKey);
    expect(stored, contains('"sass":"warm"'));
  });

  testWidgets('her voice can be muted: the switch stores it', (tester) async {
    await pumpBody(tester, tab: CompanionSettingsTab.voice);
    expect(chosen(tester).speaksReplies, isTrue);

    final row = find.byKey(const ValueKey('companion-speaks-replies'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 16));
    expect(chosen(tester).speaksReplies, isFalse);

    await pumpCompanionFrames(tester);
    final stored = await db.itemByKey(companionCustomizationKey);
    expect(stored, contains('"speaksReplies":false'));
  });

  testWidgets('offers the deepest skin tone as a seventh swatch', (
    tester,
  ) async {
    await pumpBody(tester);
    await tester.tap(
      find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone7')),
    );
    await pumpCompanionFrames(tester);
    expect(chosen(tester).skinTone, CompanionSkinTone.tone7);
    expect(
      previews(tester).first.look.palette.skin,
      CompanionSkinTone.tone7.skin,
    );
  });

  testWidgets('offers the long, wavy and ponytail styles as chips', (
    tester,
  ) async {
    await pumpBody(tester);
    for (final label in ['Long', 'Waves', 'Ponytail']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Ponytail'));
    await pumpCompanionFrames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.ponytail);
  });

  group('the eyes', () {
    testWidgets('are brown on any skin tone until a colour is picked, with no '
        'chip to match the skin', (tester) async {
      await pumpBody(
        tester,
        customization: const CompanionCustomization(
          skinTone: CompanionSkinTone.tone6,
        ),
      );
      expect(
        previews(tester).first.look.palette.iris,
        CompanionEyeColour.brown.iris,
      );
      expect(find.text('Match skin tone'), findsNothing);
    });

    testWidgets('a swatch picks the colour, which stays through a change of '
        'skin tone', (tester) async {
      await pumpBody(tester);
      await tester.tap(
        find.byKey(const ValueKey('companionSwatch-CompanionEyeColour.green')),
      );
      await pumpCompanionFrames(tester);
      expect(chosen(tester).eyeColour, CompanionEyeColour.green);
      expect(
        previews(tester).first.look.palette.iris,
        CompanionEyeColour.green.iris,
      );

      await tester.tap(
        find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone7')),
      );
      await pumpCompanionFrames(tester);
      expect(chosen(tester).eyeColour, CompanionEyeColour.green);
    });

    testWidgets('every colour says its name to a screen reader', (
      tester,
    ) async {
      await pumpBody(tester);
      for (final name in ['Dark brown', 'Hazel', 'Amber', 'Gray', 'Blue']) {
        expect(find.bySemanticsLabel(name), findsWidgets, reason: name);
      }
    });
  });

  group('the character', () {
    const grandpa = CompanionCustomization(
      character: CompanionSpecies.grandpa,
      hairStyle: CompanionHairStyle.short,
    );

    bool selected(WidgetTester tester, String label) => tester
        .widget<DesignSystemChip>(find.widgetWithText(DesignSystemChip, label))
        .selected;

    testWidgets('is Lotti until another is chosen', (tester) async {
      await pumpBody(tester, surprise: true);
      expect(selected(tester, 'Lotti'), isTrue);
      expect(selected(tester, 'Grandpa'), isFalse);
      expect(
        previews(tester).map((v) => v.look.species),
        everyElement(CompanionSpecies.grandma),
      );
    });

    testWidgets('choosing the grandpa shows him, in his own hair and a '
        'surprise outfit of his', (tester) async {
      await pumpBody(
        tester,
        surprise: true,
        customization: const CompanionCustomization(
          hairStyle: CompanionHairStyle.locs,
          outfitId: 'grandma_winter',
          skinTone: CompanionSkinTone.tone5,
        ),
      );
      await tester.tap(find.text('Grandpa'));
      await pumpCompanionFrames(tester);
      final custom = chosen(tester);
      expect(custom.character, CompanionSpecies.grandpa);
      expect(custom.outfitId, isNull);
      expect(custom.hairStyle, CompanionHairStyle.short);
      expect(custom.skinTone, CompanionSkinTone.tone5);
      expect(selected(tester, 'Grandpa'), isTrue);
      for (final view in previews(tester)) {
        expect(view.look.species, CompanionSpecies.grandpa);
        expect(view.look.palette.skin, CompanionSkinTone.tone5.skin);
      }
    });

    testWidgets("lists his outfits, not Lotti's, and dresses him in one", (
      tester,
    ) async {
      await pumpBody(tester, surprise: true, customization: grandpa);
      for (final label in ['Everyday', 'Jazz', 'Seaside', 'Market day']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Winter'), findsNothing);

      await tester.tap(find.text('Market day'));
      await pumpCompanionFrames(tester);
      expect(chosen(tester).outfitId, 'grandpa_market');
      expect(
        previews(tester).map((v) => v.look.id),
        everyElement('grandpa_market'),
      );
    });

    testWidgets('choosing the aunt shows her in her bob, among her outfits', (
      tester,
    ) async {
      await pumpBody(tester, surprise: true);
      await tester.tap(find.text('Aunt'));
      await pumpCompanionFrames(tester);
      expect(chosen(tester).character, CompanionSpecies.aunt);
      expect(chosen(tester).hairStyle, CompanionHairStyle.bob);
      expect(selected(tester, 'Aunt'), isTrue);
      for (final label in ['Studio', 'Festival', 'Weekend']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Jazz'), findsNothing);
      expect(
        previews(tester).map((v) => v.look.species),
        everyElement(CompanionSpecies.aunt),
      );
    });

    testWidgets('choosing the uncle shows him in his curls, among his '
        'outfits', (tester) async {
      await pumpBody(tester, surprise: true);
      await tester.tap(find.text('Uncle'));
      await pumpCompanionFrames(tester);
      expect(chosen(tester).character, CompanionSpecies.uncle);
      expect(chosen(tester).hairStyle, CompanionHairStyle.curls);
      expect(selected(tester, 'Uncle'), isTrue);
      for (final label in ['Night out', 'Skate park', 'Snow day']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Studio'), findsNothing);
      expect(
        previews(tester).map((v) => v.look.species),
        everyElement(CompanionSpecies.uncle),
      );
    });

    // The regression: tapping the chosen character's own chip reset its
    // hair and cleared its outfit.
    testWidgets('re-choosing the chosen character keeps its hair and outfit', (
      tester,
    ) async {
      await pumpBody(
        tester,
        surprise: true,
        customization: const CompanionCustomization(
          character: CompanionSpecies.aunt,
          hairStyle: CompanionHairStyle.locs,
          outfitId: 'aunt_studio',
        ),
      );
      await tester.tap(find.text('Aunt'));
      await pumpCompanionFrames(tester);
      expect(chosen(tester).hairStyle, CompanionHairStyle.locs);
      expect(chosen(tester).outfitId, 'aunt_studio');
    });

    testWidgets('a bare crown can be chosen for Lotti too', (tester) async {
      await pumpBody(tester);
      await tester.tap(find.text('Balding'));
      await pumpCompanionFrames(tester);
      expect(chosen(tester).hairStyle, CompanionHairStyle.balding);
      expect(chosen(tester).character, CompanionSpecies.grandma);
    });
  });

  group('the voice tab', () {
    testWidgets('without read-aloud asks only whether she answers aloud', (
      tester,
    ) async {
      await pumpBody(tester, tab: CompanionSettingsTab.voice);

      expect(
        find.byKey(const ValueKey('companion-speaks-replies')),
        findsOneWidget,
      );
      expect(find.byType(TtsVoiceSelector), findsNothing);
      expect(find.byType(TtsSpeedSelector), findsNothing);
      expect(find.byType(TtsModelSelector), findsNothing);
    });

    testWidgets('with read-aloud holds what the Speech page held: the '
        'on-device voice, the cloud voices, the speed, and under Advanced '
        'the model and preparing audio ahead — in that order', (tester) async {
      await pumpBody(tester, readAloud: true, tab: CompanionSettingsTab.voice);

      final tops = [
        tester.getTopLeft(
          find.byKey(const ValueKey('companion-speaks-replies')),
        ),
        tester.getTopLeft(find.byType(TtsVoiceSelector)),
        tester.getTopLeft(find.byType(TtsCloudVoicesSection)),
        tester.getTopLeft(find.byType(TtsSpeedSelector)),
        tester.getTopLeft(find.text('Advanced')),
        tester.getTopLeft(find.byType(TtsModelSelector)),
        tester.getTopLeft(find.text('Prepare chat audio automatically')),
      ].map((offset) => offset.dy).toList();
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(tops.length));
    });

    testWidgets('a voice picked there is her voice, and noted as the '
        "user's own pick; a speed and preparing ahead are stored too", (
      tester,
    ) async {
      await pumpBody(tester, readAloud: true, tab: CompanionSettingsTab.voice);
      expect(voiceSettings(tester).voiceId, 'F1');
      expect(voiceSettings(tester).voicePicked, isFalse);

      await tester.tap(find.text('Female 3'));
      await tester.pump();
      expect(voiceSettings(tester).voiceId, 'F3');
      expect(voiceSettings(tester).voicePicked, isTrue);

      // A segment draws its label twice, to hold its width when selected.
      final faster = find
          .descendant(
            of: find.byType(TtsSpeedSelector),
            matching: find.text('1.5'),
          )
          .last;
      await tester.ensureVisible(faster);
      await tester.tap(faster);
      await tester.pump();
      expect(voiceSettings(tester).speed, 1.5);

      final prepare = find.text('Prepare chat audio automatically');
      await tester.ensureVisible(prepare);
      await tester.tap(prepare);
      await tester.pump();
      expect(voiceSettings(tester).autoPrepareChatAudio, isTrue);
      await pumpCompanionFrames(tester);
    });
  });

  group('her voice follows her character', () {
    testWidgets('the grandpa and the uncle speak with a male voice, Lotti '
        "and the aunt with a female one, keeping the voice's number", (
      tester,
    ) async {
      await pumpBody(tester);
      expect(voiceSettings(tester).voiceId, 'F1');

      for (final (character, voiceId) in [
        ('Grandpa', 'M1'),
        ('Aunt', 'F1'),
        ('Uncle', 'M1'),
        ('Lotti', 'F1'),
      ]) {
        await tester.tap(find.text(character));
        await pumpCompanionFrames(tester);
        expect(voiceSettings(tester).voiceId, voiceId, reason: character);
        // Followed, not picked: it goes on following.
        expect(voiceSettings(tester).voicePicked, isFalse, reason: character);
      }
    });

    testWidgets('only until the user picks a voice: after, a change of '
        'character leaves the voice alone', (tester) async {
      await pumpBody(tester, readAloud: true, tab: CompanionSettingsTab.voice);
      await tester.tap(find.text('Female 2'));
      await tester.pump();

      await openCompanionSettingsTab(tester, CompanionSettingsTab.look);
      await tester.tap(find.text('Grandpa'));
      await pumpCompanionFrames(tester);

      expect(chosen(tester).character, CompanionSpecies.grandpa);
      expect(voiceSettings(tester).voiceId, 'F2');
    });
  });
}
