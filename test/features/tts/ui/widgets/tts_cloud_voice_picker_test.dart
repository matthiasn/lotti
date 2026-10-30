import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voice_picker.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_radio_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart' show MockDomainLogger, MockIoFile;
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../test_utils.dart';

void main() {
  final service = (
    provider: testInferenceProvider(
      id: 'mistral',
      inferenceProviderType: InferenceProviderType.mistral,
    ),
    model: testAiModel(id: 'voice-row', providerModelId: 'voxtral-mini-tts'),
  );

  /// [female] female and [male] male English voices; the first female is
  /// the default. Every third voice carries mood tags.
  VoxtralVoiceCatalog catalogOf({int female = 2, int male = 1}) =>
      VoxtralVoiceCatalog(
        fetchedAt: DateTime.utc(2026, 10, 27),
        voices: [
          for (var i = 0; i < female; i++)
            VoxtralVoice(
              id: 'f$i',
              name: 'Female voice $i',
              gender: 'female',
              languages: const ['en_us'],
              tags: i == 1 ? const ['sunny', 'easygoing'] : const [],
              type: VoxtralVoiceType.preset,
            ),
          for (var i = 0; i < male; i++)
            VoxtralVoice(
              id: 'm$i',
              name: 'Male voice $i',
              gender: 'male',
              languages: const ['en_us'],
              type: VoxtralVoiceType.preset,
            ),
        ],
      );

  late FakeCloudSpeechSynthesizer cloud;
  late FakeTtsAudioPlayer player;
  late ProviderContainer container;
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
    cloud = FakeCloudSpeechSynthesizer();
    player = FakeTtsAudioPlayer();
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester,
    VoxtralVoiceCatalog catalog, {
    Map<String, String> stored = const {},
  }) async {
    when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
      (_) async => {ttsCloudVoicesKey: jsonEncode(stored)},
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(600, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            // The picker reads the pick it opened with on its first build,
            // so it is shown once the stored settings have loaded — as on
            // the page, where the settings are long loaded by then.
            final loaded = ref
                .watch(ttsSettingsControllerProvider)
                .cloudVoiceByLanguage;
            if (stored.isNotEmpty && loaded.isEmpty) {
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              child: CloudVoicePicker(
                service: service,
                catalog: catalog,
                language: 'en',
              ),
            );
          },
        ),
        overrides: [
          cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          ttsAudioPlayerProvider.overrideWithValue(player),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TtsVoiceRadioRow>(
      find.byType(TtsVoiceRadioRow),
    ))
      row.title,
  ];

  Map<String, String> picks() =>
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage;

  testWidgets('a short list shows every voice, the default first and '
      'tagged, with gender and mood as its caption', (tester) async {
    await pump(tester, catalogOf());

    expect(find.byType(DsSegmentedToggle<String>), findsNothing);
    expect(rowTitles(tester), [
      'Female voice 0',
      'Female voice 1',
      'Male voice 0',
    ]);
    expect(find.text('Default'), findsOneWidget);
    expect(
      find.text('Female · sunny, easygoing', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Male', findRichText: true), findsOneWidget);
    final selected = tester.widget<TtsVoiceRadioRow>(
      find.byType(TtsVoiceRadioRow).first,
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('a long list of both genders is filtered by a toggle, below '
      'the pinned default', (tester) async {
    await pump(tester, catalogOf(female: 5, male: 5));

    expect(find.byType(DsSegmentedToggle<String>), findsOneWidget);
    // The default, then the female rest; gender is the filter, not a caption.
    expect(rowTitles(tester), [
      'Female voice 0',
      'Female voice 1',
      'Female voice 2',
      'Female voice 3',
      'Female voice 4',
    ]);
    expect(find.text('sunny, easygoing', findRichText: true), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(DsSegmentedToggle<String>)).dy,
      greaterThan(tester.getTopLeft(find.text('Female voice 0')).dy),
    );

    await tester.tap(find.text('Male').first);
    await tester.pumpAndSettle();
    expect(rowTitles(tester), [
      'Female voice 0',
      for (var i = 0; i < 5; i++) 'Male voice $i',
    ]);
  });

  testWidgets('a pick the filter hides is still named', (tester) async {
    await pump(tester, catalogOf(female: 5, male: 5));

    await tester.tap(find.text('Male').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male voice 1'));
    await tester.pumpAndSettle();
    expect(find.text('In use: Male voice 1'), findsNothing);

    await tester.tap(find.text('Female').first);
    await tester.pumpAndSettle();
    expect(find.text('Male voice 1'), findsNothing);
    expect(find.text('In use: Male voice 1'), findsOneWidget);
  });

  testWidgets('the filter opens on the gender of the picked voice', (
    tester,
  ) async {
    await pump(tester, catalogOf(female: 5, male: 5), stored: {'en': 'm3'});

    // Default and the opened-with pick are pinned; the male rest follows.
    expect(rowTitles(tester), [
      'Female voice 0',
      'Male voice 3',
      'Male voice 0',
      'Male voice 1',
      'Male voice 2',
      'Male voice 4',
    ]);
  });

  testWidgets('a tap picks the voice and plays it, and the sheet stays', (
    tester,
  ) async {
    await pump(tester, catalogOf());

    await tester.tap(find.text('Male voice 0'));
    await tester.pump();

    expect(picks(), {'en': 'm0'});
    final call = cloud.calls.single;
    expect(call.route.voiceId, 'm0');
    expect(call.route.languageCode, 'en');
    expect(
      call.text,
      'Hello! This is how I sound reading your summaries aloud.',
    );
    await tester.pumpAndSettle();
    expect(find.byType(CloudVoicePicker), findsOneWidget);
    expect(
      tester
          .widget<TtsVoiceRadioRow>(
            find.ancestor(
              of: find.text('Male voice 0'),
              matching: find.byType(TtsVoiceRadioRow),
            ),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('a tap while a sample still plays stops it and auditions the '
      'newly picked voice', (tester) async {
    final file = MockIoFile();
    when(() => file.path).thenReturn('/tmp/sample.wav');
    when(file.existsSync).thenReturn(true);
    when(file.delete).thenAnswer((_) async => file);
    cloud = FakeCloudSpeechSynthesizer(output: file);
    addTearDown(player.dispose);
    await pump(tester, catalogOf());

    await tester.tap(find.text('Female voice 1'));
    await tester.pumpAndSettle();
    expect(player.playCount, 1);

    // The first sample is still playing: the second tap must not be lost.
    await tester.tap(find.text('Male voice 0'));
    await tester.pumpAndSettle();

    expect(picks(), {'en': 'm0'});
    expect(cloud.calls.map((c) => c.route.voiceId), ['f1', 'm0']);
    expect(player.stopCount, greaterThanOrEqualTo(1));
    expect(player.playCount, 2);
  });

  testWidgets('a voice without a female or male gender stays reachable '
      'under either filter', (tester) async {
    final base = catalogOf(female: 5, male: 5);
    await pump(
      tester,
      VoxtralVoiceCatalog(
        fetchedAt: base.fetchedAt,
        voices: [
          ...base.voices,
          const VoxtralVoice(
            id: 'n0',
            name: 'Unlabelled voice',
            languages: ['en_us'],
          ),
        ],
      ),
    );

    expect(find.text('Unlabelled voice'), findsOneWidget);
    await tester.tap(find.text('Male').first);
    await tester.pumpAndSettle();
    expect(find.text('Unlabelled voice'), findsOneWidget);
  });

  testWidgets('picking the default clears the choice rather than pinning '
      'it', (tester) async {
    await pump(tester, catalogOf(), stored: {'en': 'm0'});

    await tester.tap(find.text('Female voice 0'));
    await tester.pump();

    expect(picks(), isEmpty);
  });

  testWidgets('the pick the sheet opened with stays pinned while others are '
      'tried', (tester) async {
    await pump(tester, catalogOf(female: 3), stored: {'en': 'f2'});

    expect(rowTitles(tester).take(2), ['Female voice 0', 'Female voice 2']);
    // While still in use it is the user's pick, as the page calls it.
    expect(find.text('Your pick'), findsOneWidget);
    expect(find.text('Previous'), findsNothing);
    await tester.tap(find.text('Female voice 1'));
    await tester.pumpAndSettle();

    expect(picks(), {'en': 'f1'});
    expect(rowTitles(tester).take(2), ['Female voice 0', 'Female voice 2']);
    // Now it is the way back, labelled as such.
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Your pick'), findsNothing);
  });

  testWidgets('only the picked voice keeps a speaker, named for it, which '
      'replays it and changes nothing', (tester) async {
    await pump(tester, catalogOf(), stored: {'en': 'm0'});

    expect(find.text('Tap a voice to hear it and use it.'), findsOneWidget);
    expect(find.byType(CloudVoicePreviewButton), findsOneWidget);
    expect(find.bySemanticsLabel('Listen to Male voice 0'), findsOneWidget);

    await tester.tap(find.byType(CloudVoicePreviewButton));
    await tester.pump();

    expect(cloud.calls.single.route.voiceId, 'm0');
    expect(picks(), {'en': 'm0'});
  });
}
