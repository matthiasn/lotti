import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_settings_sections.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(WidgetTester tester, Widget section) async {
    await tester.pumpWidget(makeTestableWidget(section));
    await tester.pumpAndSettle();
  }

  TtsSettings settings(WidgetTester tester, Type section) =>
      ProviderScope.containerOf(
        tester.element(find.byType(section)),
      ).read(ttsSettingsControllerProvider);

  group('TtsVoiceSection', () {
    testWidgets('shows the stored voice under its heading', (tester) async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {ttsVoiceIdKey: 'M2', ttsVoicePickedKey: 'true'},
      );
      await pump(tester, const TtsVoiceSection());

      expect(find.text('On-device voice'), findsOneWidget);
      expect(find.text('For profiles without a cloud voice'), findsOneWidget);
      expect(
        tester.widget<TtsVoiceSelector>(find.byType(TtsVoiceSelector)).voiceId,
        'M2',
      );
      expect(
        tester.getTopLeft(find.text('On-device voice')).dy,
        lessThan(tester.getTopLeft(find.byType(TtsVoiceSelector)).dy),
      );
    });

    testWidgets("a voice tapped is stored as the user's own pick", (
      tester,
    ) async {
      await pump(tester, const TtsVoiceSection());
      await tester.tap(find.text('Female 2'));
      await tester.pump();

      expect(settings(tester, TtsVoiceSection).voiceId, 'F2');
      expect(settings(tester, TtsVoiceSection).voicePicked, isTrue);
      expect(
        tester.widget<TtsVoiceSelector>(find.byType(TtsVoiceSelector)).voiceId,
        'F2',
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, 'F2'),
      ).called(1);
    });
  });

  group('TtsSpeedSection', () {
    testWidgets('shows the stored speed under its heading, and stores the '
        'one tapped', (tester) async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {ttsSpeedKey: '1.25'},
      );
      await pump(tester, const TtsSpeedSection());

      expect(find.text('Reading speed'), findsOneWidget);
      expect(find.text('How fast summaries are read'), findsOneWidget);
      TtsSpeedSelector selector() =>
          tester.widget<TtsSpeedSelector>(find.byType(TtsSpeedSelector));
      expect(selector().value, 1.25);

      // A segment draws its label twice, to hold its width when selected.
      await tester.tap(find.text('1.5').last);
      await tester.pump();

      expect(selector().value, 1.5);
      verify(
        () => mocks.settingsDb.saveSettingsItem(ttsSpeedKey, '1.5'),
      ).called(1);
    });
  });

  group('TtsAutoPrepareRow', () {
    DesignSystemSelectionRow row(WidgetTester tester) => tester.widget(
      find.byType(DesignSystemSelectionRow),
    );

    testWidgets('toggles preparing ahead and stores each choice', (
      tester,
    ) async {
      await pump(tester, const Material(child: TtsAutoPrepareRow()));
      expect(row(tester).selected, isFalse);

      await tester.tap(find.text('Prepare chat audio automatically'));
      await tester.pump();
      expect(row(tester).selected, isTrue);
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          ttsAutoPrepareChatAudioKey,
          'true',
        ),
      ).called(1);

      await tester.tap(find.text('Prepare chat audio automatically'));
      await tester.pump();
      expect(row(tester).selected, isFalse);
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          ttsAutoPrepareChatAudioKey,
          'false',
        ),
      ).called(1);
    });

    testWidgets('explains itself only where it is described', (tester) async {
      const explanation =
          'Prepare new chat replies on this device so playback starts '
          'sooner. Audio plays only when you tap play.';
      await pump(tester, const Material(child: TtsAutoPrepareRow()));
      expect(row(tester).subtitle, isNull);
      expect(find.text(explanation), findsNothing);

      await pump(
        tester,
        const Material(child: TtsAutoPrepareRow(described: true)),
      );
      expect(find.text(explanation), findsOneWidget);
    });
  });
}
