import 'dart:math' as math;

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
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../companion_overrides.dart';

/// She ticks for as long as she is mounted: pump frames, never settle —
/// past the quarter second a change waits before it is sent.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

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
    Widget body = const CompanionSettingsBody(),
    bool surprise = false,
  }) async {
    setTestSurfaceSize(tester, const Size(800, 1600));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(child: body),
        overrides: [
          settingsDbProvider.overrideWithValue(db),
          outboxServiceProvider.overrideWithValue(outbox),
          if (surprise) ...[
            companionOutfitSeedProvider.overrideWithValue(7),
            companionCustomizationProvider.overrideWithBuild(
              (ref, notifier) => customization,
            ),
          ] else
            ...companionLookOverrides(
              outfit: CompanionLook.grandmaGarden,
              customization: customization,
            ),
        ],
      ),
    );
    await _frames(tester);
  }

  CompanionCustomization chosen(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(CompanionSettingsBody)),
      ).read(companionCustomizationProvider);

  List<CompanionView> previews(WidgetTester tester) =>
      tester.widgetList<CompanionView>(find.byType(CompanionView)).toList();

  testWidgets('shows her head to toe and as a portrait, in what is chosen', (
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
      'Skin tone',
      'Hairstyle',
      'Hair color',
      'Sass',
      'Outfit',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
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
    await _frames(tester);

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
    await _frames(tester);

    expect(chosen(tester).skinTone, CompanionSkinTone.tone6);
    semantics.dispose();
  });

  testWidgets('a hairstyle chip changes her hair', (tester) async {
    await pumpBody(tester);
    await tester.tap(find.text('Afro'));
    await _frames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.afro);
    expect(previews(tester).last.look.hairStyle, CompanionHairStyle.afro);
  });

  testWidgets('a hair colour swatch changes her hair colour', (tester) async {
    await pumpBody(tester);
    await tester.tap(
      find.byKey(const ValueKey('companionSwatch-CompanionHairColour.pink')),
    );
    await _frames(tester);
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
    await _frames(tester);
    expect(chosen(tester).outfitId, 'grandma_winter');
    expect(selected('Winter'), isTrue);
    expect(selected('Surprise me'), isFalse);

    await tester.tap(find.text('Surprise me'));
    await _frames(tester);
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
    await _frames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.afro);
    expect(
      previews(tester).map((v) => v.look.hairStyle),
      everyElement(CompanionHairStyle.afro),
    );
    expect(previews(tester).map((v) => v.look.id), everyElement(expected));
  });

  testWidgets('the character and outfit pickers sit right under her '
      'preview, above the other choices', (tester) async {
    await pumpBody(tester);
    final previewBottom = [
      tester.getRect(find.byKey(const ValueKey('companionSettingsFull'))),
      tester.getRect(find.byKey(const ValueKey('companionSettingsBust'))),
    ].map((r) => r.bottom).reduce(math.max);
    final characterTop = tester.getTopLeft(find.text('Character')).dy;
    final outfitTop = tester.getTopLeft(find.text('Outfit')).dy;
    expect(characterTop, greaterThan(previewBottom));
    expect(outfitTop, greaterThan(characterTop));
    expect(
      tester.getTopLeft(find.text('Surprise me')).dy,
      lessThan(tester.getTopLeft(find.text('Skin tone')).dy),
    );
  });

  testWidgets('every choice is stored as it is made, and sent to the other '
      'devices', (tester) async {
    await pumpBody(tester);
    await tester.tap(find.text('Locs').last);
    await _frames(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
    await pumpBody(tester);
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

    await _frames(tester);
    final stored = await db.itemByKey(companionCustomizationKey);
    expect(stored, contains('"sass":"warm"'));
  });

  testWidgets('her voice can be muted: the switch stores it', (tester) async {
    await pumpBody(tester);
    expect(chosen(tester).speaksReplies, isTrue);

    final row = find.byKey(const ValueKey('companion-speaks-replies'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 16));
    expect(chosen(tester).speaksReplies, isFalse);

    await _frames(tester);
    final stored = await db.itemByKey(companionCustomizationKey);
    expect(stored, contains('"speaksReplies":false'));
  });

  testWidgets('the page wears the settings chrome and its title', (
    tester,
  ) async {
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<UserActivityService>(
        UserActivityService(),
      ),
    );
    addTearDown(tearDownTestGetIt);
    setTestSurfaceSize(tester, const Size(800, 1600));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CompanionSettingsPage(),
        overrides: [
          settingsDbProvider.overrideWithValue(db),
          outboxServiceProvider.overrideWithValue(outbox),
          ...companionLookOverrides(),
        ],
      ),
    );
    // Past the page's fade-in, so no timer is left at teardown.
    await tester.pump(const Duration(milliseconds: 500));
    final page = tester.widget<SliverBoxAdapterPage>(
      find.byType(SliverBoxAdapterPage),
    );
    expect(page.title, 'Companion');
    expect(page.showBackButton, isTrue);
    expect(find.byType(CompanionSettingsBody), findsOneWidget);
  });

  test('every part and outfit has its own name', () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(
      CompanionHairStyle.values.map((s) => hairStyleName(m, s)).toSet(),
      hasLength(CompanionHairStyle.values.length),
    );
    expect(
      CompanionHairColour.values.map((c) => hairColourName(m, c)).toSet(),
      hasLength(CompanionHairColour.values.length),
    );
    for (final species in CompanionSpecies.choosable) {
      final outfits = CompanionLook.of(species);
      expect(
        outfits.map((o) => outfitName(m, o)).toSet(),
        hasLength(outfits.length),
        reason: species.name,
      );
    }
    expect(
      CompanionSpecies.choosable.map((s) => characterName(m, s)).toList(),
      ['Lotti', 'Grandpa', 'Aunt', 'Uncle'],
    );
    expect(
      CompanionSass.values.map((s) => sassName(m, s)).toSet(),
      hasLength(CompanionSass.values.length),
    );
  });

  test("each character's first outfit is called Everyday", () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(outfitName(m, CompanionLook.grandma), 'Everyday');
    expect(outfitName(m, CompanionLook.grandpa), 'Everyday');
    expect(
      [
        CompanionLook.grandpaJazz,
        CompanionLook.grandpaSeaside,
        CompanionLook.grandpaMarket,
      ].map((o) => outfitName(m, o)),
      ['Jazz', 'Seaside', 'Market day'],
    );
    expect(outfitName(m, CompanionLook.aunt), 'Everyday');
    expect(
      [
        CompanionLook.auntStudio,
        CompanionLook.auntFestival,
        CompanionLook.auntWeekend,
      ].map((o) => outfitName(m, o)),
      ['Studio', 'Festival', 'Weekend'],
    );
    expect(outfitName(m, CompanionLook.uncle), 'Everyday');
    expect(
      [
        CompanionLook.uncleNight,
        CompanionLook.uncleSkate,
        CompanionLook.uncleSnow,
      ].map((o) => outfitName(m, o)),
      ['Night out', 'Skate park', 'Snow day'],
    );
  });

  testWidgets('offers the deepest skin tone as a seventh swatch', (
    tester,
  ) async {
    await pumpBody(tester);
    await tester.tap(
      find.byKey(const ValueKey('companionSwatch-CompanionSkinTone.tone7')),
    );
    await _frames(tester);
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
    await _frames(tester);
    expect(chosen(tester).hairStyle, CompanionHairStyle.ponytail);
  });

  group('the eyes', () {
    bool matching(WidgetTester tester) => tester
        .widget<DesignSystemChip>(
          find.widgetWithText(DesignSystemChip, 'Match skin tone'),
        )
        .selected;

    testWidgets('match the skin tone until a colour is picked', (tester) async {
      await pumpBody(
        tester,
        customization: const CompanionCustomization(
          skinTone: CompanionSkinTone.tone6,
        ),
      );
      expect(matching(tester), isTrue);
      expect(
        previews(tester).first.look.palette.iris,
        CompanionSkinTone.tone6.eyes.iris,
      );
    });

    testWidgets('a swatch picks the colour, and the chip lets them match '
        'again', (tester) async {
      await pumpBody(tester);
      await tester.tap(
        find.byKey(const ValueKey('companionSwatch-CompanionEyeColour.green')),
      );
      await _frames(tester);
      expect(chosen(tester).eyeColour, CompanionEyeColour.green);
      expect(matching(tester), isFalse);
      expect(
        previews(tester).first.look.palette.iris,
        CompanionEyeColour.green.iris,
      );

      await tester.tap(find.text('Match skin tone'));
      await _frames(tester);
      expect(chosen(tester).eyeColour, isNull);
      expect(matching(tester), isTrue);
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

  test('every eye colour has its own name', () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(
      CompanionEyeColour.values.map((e) => eyeColourName(m, e)).toSet(),
      hasLength(CompanionEyeColour.values.length),
    );
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
      await _frames(tester);
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
      await _frames(tester);
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
      await _frames(tester);
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
      await _frames(tester);
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
      await _frames(tester);
      expect(chosen(tester).hairStyle, CompanionHairStyle.locs);
      expect(chosen(tester).outfitId, 'aunt_studio');
    });

    testWidgets('a bare crown can be chosen for Lotti too', (tester) async {
      await pumpBody(tester);
      await tester.tap(find.text('Balding'));
      await _frames(tester);
      expect(chosen(tester).hairStyle, CompanionHairStyle.balding);
      expect(chosen(tester).character, CompanionSpecies.grandma);
    });
  });
}
