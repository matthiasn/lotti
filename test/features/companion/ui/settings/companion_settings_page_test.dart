import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_tabs.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
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

  const phone = Size(390, 844);
  const pane = Size(1100, 800);

  Future<void> pump(
    WidgetTester tester, {
    Size size = phone,
    bool readAloud = true,
    bool engineSupported = true,
    RecordingVoice? voice,
  }) => pumpCompanionSettings(
    tester,
    db: db,
    outbox: outbox,
    size: size,
    readAloud: readAloud,
    engineSupported: engineSupported,
    voice: voice,
  );

  Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));
  Rect tabsRect(WidgetTester tester) => rectOf(
    tester,
    CompanionSettingsKeys.tab(CompanionSettingsTab.look),
  );
  DesignSystemButton hear(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(find.byKey(CompanionSettingsKeys.hear));

  group('she stays in sight', () {
    testWidgets('on a phone she stands over the tabs, no taller than her '
        'card, and does not move when her choices scroll', (tester) async {
      await pump(tester);

      final full = rectOf(tester, CompanionSettingsKeys.full);
      final bust = rectOf(tester, CompanionSettingsKeys.bust);
      expect(full.height, bust.height);
      expect(full.height, lessThanOrEqualTo(ControlSizes.companionCard));
      expect(full.right, lessThanOrEqualTo(bust.left));
      expect(full.bottom, lessThan(tabsRect(tester).top));

      final content = find.byKey(
        CompanionSettingsKeys.content(CompanionSettingsTab.look),
      );
      final firstChoice = tester.getTopLeft(find.text('Character')).dy;
      await tester.drag(content, const Offset(0, -300));
      await pumpCompanionFrames(tester);

      expect(
        tester.getTopLeft(find.text('Character')).dy,
        lessThan(firstChoice),
      );
      expect(rectOf(tester, CompanionSettingsKeys.full), full);
      expect(rectOf(tester, CompanionSettingsKeys.bust), bust);
      expect(tester.takeException(), isNull);
    });

    testWidgets('over her choices she is capped at her card however much '
        'width there is to grow into', (tester) async {
      // Under the width at which she moves beside them.
      await pump(tester, size: const Size(620, 844));

      final full = rectOf(tester, CompanionSettingsKeys.full);
      expect(full.bottom, lessThan(tabsRect(tester).top));
      expect(full.height, ControlSizes.companionCard);
    });

    testWidgets('on a wide pane she stands beside her choices, larger, with '
        'hear me under her', (tester) async {
      await pump(tester, size: pane);

      final full = rectOf(tester, CompanionSettingsKeys.full);
      final bust = rectOf(tester, CompanionSettingsKeys.bust);
      expect(bust.right, lessThan(tabsRect(tester).left));
      expect(full.height, greaterThan(ControlSizes.companionCard));
      expect(full.height, lessThanOrEqualTo(ControlSizes.companionCard * 2));
      expect(full.height, bust.height);
      expect(
        rectOf(tester, CompanionSettingsKeys.hear).top,
        greaterThanOrEqualTo(full.bottom),
      );
      // Her choices start level with her, not under her.
      expect(tabsRect(tester).top, lessThan(full.bottom));
    });

    testWidgets('both of her stand on the stage in what is chosen, still '
        'unless cued, and do not blink as one', (tester) async {
      await pump(tester);

      final speakers = tester
          .widgetList<CompanionSpeaker>(find.byType(CompanionSpeaker))
          .toList();
      expect(speakers.map((s) => s.framing), [
        CompanionFraming.full,
        CompanionFraming.bust,
      ]);
      for (final speaker in speakers) {
        expect(speaker.sourceId, companionSettingsVoiceSource);
        expect(speaker.dressedFor, companionSettingsDressedFor);
        expect(speaker.stage, isTrue);
        expect(speaker.autoGestures, isFalse);
      }
      expect(speakers.first.controller, isNotNull);
      expect(speakers.first.seed, isNot(speakers.last.seed));
      for (final view in tester.widgetList<CompanionView>(
        find.byType(CompanionView),
      )) {
        expect(view.look.id, CompanionLook.grandmaGarden.id);
      }
    });
  });

  group('her choices are sorted into three tabs', () {
    testWidgets('look first; a tab shows its own choices and only those, '
        'and says it is the one selected', (tester) async {
      await pump(tester);

      Iterable<bool> selected() => tester
          .widgetList<DesignSystemTab>(find.byType(DesignSystemTab))
          .map((tab) => tab.selected);
      expect(
        tester
            .widgetList<DesignSystemTab>(find.byType(DesignSystemTab))
            .map((tab) => tab.label),
        ['Look', 'Voice', 'Personality'],
      );
      expect(selected(), [true, false, false]);
      expect(find.byType(CompanionLookTab), findsOneWidget);

      await openCompanionSettingsTab(tester, CompanionSettingsTab.voice);
      expect(selected(), [false, true, false]);
      expect(find.byType(CompanionVoiceTab), findsOneWidget);
      expect(find.byType(CompanionLookTab), findsNothing);

      await openCompanionSettingsTab(tester, CompanionSettingsTab.personality);
      expect(selected(), [false, false, true]);
      expect(find.byType(CompanionPersonalityTab), findsOneWidget);
      expect(find.byType(CompanionVoiceTab), findsNothing);
    });

    testWidgets('where the three labels fit they share the width equally; '
        'where they do not they keep their labels whole and scroll', (
      tester,
    ) async {
      // At a text size no font fits three labels into a phone's width
      // with: nothing overflows, and the last tab scrolls in.
      await pumpCompanionSettings(
        tester,
        db: db,
        outbox: outbox,
        size: phone,
        child: const MediaQuery(
          data: MediaQueryData(size: phone, textScaler: TextScaler.linear(4)),
          child: Scaffold(body: CompanionSettingsBody()),
        ),
      );
      expect(tester.takeException(), isNull);
      final last = find.byKey(
        CompanionSettingsKeys.tab(CompanionSettingsTab.personality),
      );
      final before = tester.getRect(last);
      expect(before.right, greaterThan(phone.width));
      await tester.ensureVisible(last);
      await pumpCompanionFrames(tester);
      // Whole, as wide as it was, and moved into the row's view.
      expect(tester.getRect(last).width, before.width);
      expect(tester.getRect(last).left, lessThan(before.left));

      // On a pane with room they are equal thirds of their row.
      await pump(tester, size: const Size(1600, 800));
      final widths = {
        for (final tab in CompanionSettingsTab.values)
          tester.getSize(find.byKey(CompanionSettingsKeys.tab(tab))).width,
      };
      expect(widths, hasLength(1));
    });

    testWidgets('a tab opens at its top, not where another was scrolled to', (
      tester,
    ) async {
      await pump(tester);
      await tester.drag(
        find.byKey(CompanionSettingsKeys.content(CompanionSettingsTab.look)),
        const Offset(0, -300),
      );
      await pumpCompanionFrames(tester);

      await openCompanionSettingsTab(tester, CompanionSettingsTab.voice);

      expect(
        tester.getTopLeft(find.text('Answer spoken questions aloud')).dy,
        greaterThan(tabsRect(tester).bottom),
      );
    });
  });

  group('hear me', () {
    testWidgets('has her say a sample line in the voice chosen, then offers '
        'to stop it', (tester) async {
      final voice = RecordingVoice();
      await pump(tester, voice: voice);
      expect(hear(tester).label, 'Hear me');
      expect(hear(tester).leadingIcon, LottiIcons.volume);

      await tester.tap(find.byKey(CompanionSettingsKeys.hear));
      await pumpCompanionFrames(tester);

      expect(voice.spoken, [
        (
          sourceId: companionSettingsVoiceSource,
          text: 'Hello! This is how I sound reading your summaries aloud.',
        ),
      ]);
      expect(hear(tester).label, 'Stop');
      expect(hear(tester).leadingIcon, LottiIcons.stop);

      await tester.tap(find.byKey(CompanionSettingsKeys.hear));
      await pumpCompanionFrames(tester);

      expect(voice.stopped, [companionSettingsVoiceSource]);
      expect(voice.spoken, hasLength(1));
      expect(hear(tester).label, 'Hear me');
    });

    testWidgets('asks before the voice model is downloaded for it', (
      tester,
    ) async {
      final voice = RecordingVoice();
      await pump(tester, voice: voice);
      await tester.tap(find.byKey(CompanionSettingsKeys.hear));
      await pumpCompanionFrames(tester);

      final answer = voice.confirmModelDownload!(kTtsModels.first);
      await pumpCompanionFrames(tester);
      expect(find.text('Download the voice model?'), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await pumpCompanionFrames(tester);
      expect(await answer, isFalse);
    });

    testWidgets('is not offered without a voice to hear: read-aloud off, '
        'or no on-device voice on this platform', (tester) async {
      await pump(tester, readAloud: false);
      expect(find.byKey(CompanionSettingsKeys.hear), findsNothing);

      await pump(tester, engineSupported: false);
      expect(find.byKey(CompanionSettingsKeys.hear), findsNothing);
      // She is there all the same.
      expect(find.byKey(CompanionSettingsKeys.bust), findsOneWidget);
    });

    testWidgets('leaving the page ends her sample', (tester) async {
      final voice = RecordingVoice();
      await pump(tester, voice: voice);
      await tester.tap(find.byKey(CompanionSettingsKeys.hear));
      await pumpCompanionFrames(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(voice.stopped, [companionSettingsVoiceSource]);
    });
  });

  testWidgets('the page wears the settings chrome and its title, and gives '
      'her settings the height left under it', (tester) async {
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<UserActivityService>(
        UserActivityService(),
      ),
    );
    addTearDown(tearDownTestGetIt);
    await pumpCompanionSettings(
      tester,
      db: db,
      outbox: outbox,
      size: phone,
      child: const CompanionSettingsPage(),
    );
    // Past the page's fade-in, so no timer is left at teardown.
    await tester.pump(const Duration(milliseconds: 500));

    final page = tester.widget<SliverBoxAdapterPage>(
      find.byType(SliverBoxAdapterPage),
    );
    expect(page.title, 'Companion');
    expect(page.showBackButton, isTrue);
    expect(page.fillRemaining, isTrue);
    expect(find.byType(CompanionSettingsBody), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
