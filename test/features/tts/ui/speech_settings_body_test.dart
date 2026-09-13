import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/ui/speech_settings_body.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  testWidgets('renders Voice, Model and Reading-speed sections + selectors', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(const SpeechSettingsBody()));
    await tester.pumpAndSettle();

    // Section titles (entity-definition SettingsFormSection headers).
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Reading speed'), findsOneWidget);

    expect(find.byType(TtsVoiceSelector), findsOneWidget);
    expect(find.byType(TtsModelSelector), findsOneWidget);
    expect(find.byType(TtsSpeedSelector), findsOneWidget);
  });

  testWidgets('chat audio checkbox persists its choice without playback', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(const SpeechSettingsBody()));
    await tester.pumpAndSettle();
    final row = find.byType(DesignSystemSelectionRow);
    expect(tester.widget<DesignSystemSelectionRow>(row).selected, isFalse);
    await tester.tap(find.text('Prepare chat audio automatically'));
    await tester.pump();
    expect(tester.widget<DesignSystemSelectionRow>(row).selected, isTrue);
    verify(
      () =>
          mocks.settingsDb.saveSettingsItem(ttsAutoPrepareChatAudioKey, 'true'),
    ).called(1);
    await tester.tap(row);
    await tester.pump();
    expect(tester.widget<DesignSystemSelectionRow>(row).selected, isFalse);
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        ttsAutoPrepareChatAudioKey,
        'false',
      ),
    ).called(1);
  });

  testWidgets('selecting a voice persists it through the controller', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(const SpeechSettingsBody()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Female 2'));
    await tester.pump();

    verify(
      () => mocks.settingsDb.saveSettingsItem(ttsVoiceIdKey, 'F2'),
    ).called(1);
  });
}
