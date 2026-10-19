import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
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
  }) async {
    setTestSurfaceSize(tester, const Size(800, 1600));
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(child: body),
        overrides: [
          settingsDbProvider.overrideWithValue(db),
          outboxServiceProvider.overrideWithValue(outbox),
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

  testWidgets('a hairstyle segment changes her hair', (tester) async {
    await pumpBody(tester);
    // The visible label; the toggle lays an invisible bold twin under it.
    await tester.tap(find.text('Afro').last);
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
    expect(
      companionOutfits.map((o) => outfitName(m, o)).toSet(),
      hasLength(companionOutfits.length),
    );
  });
}
