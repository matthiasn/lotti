import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voice_picker.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voices_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart' show MockDomainLogger, MockIoFile;
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../test_utils.dart';

void main() {
  final mistral = testInferenceProvider(
    id: 'mistral',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final voiceModel = testAiModel(
    id: 'voice-row',
    providerModelId: 'voxtral-mini-tts-3-0',
    inferenceProviderId: 'mistral',
  );
  // The test locale is English: English is the user's own language.
  final catalog = VoxtralVoiceCatalog(
    fetchedAt: DateTime.utc(2026, 10, 27),
    voices: const [
      VoxtralVoice(
        id: 'v-en-f',
        name: 'Ada',
        gender: 'female',
        languages: ['en_us'],
        type: VoxtralVoiceType.preset,
      ),
      VoxtralVoice(id: 'v-en-m', name: 'Bram', languages: ['en_us']),
      VoxtralVoice(id: 'v-de', name: 'Heidi', languages: ['de']),
      VoxtralVoice(id: 'v-ca', name: 'Núria', languages: ['ca']),
      VoxtralVoice(id: 'v-fr-1', name: 'Amélie', languages: ['fr']),
      VoxtralVoice(id: 'v-fr-2', name: 'Damien', languages: ['fr']),
    ],
  );
  final services = <CloudVoiceService>[(provider: mistral, model: voiceModel)];

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

  /// Stored picks, as the settings controller loads them on first read.
  void storePicks(Map<String, String> picks) {
    when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
      (_) async => {ttsCloudVoicesKey: jsonEncode(picks)},
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    List<CloudVoiceService> services = const [],
    FutureOr<VoxtralVoiceCatalog> Function()? loadCatalog,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const SingleChildScrollView(child: TtsCloudVoicesSection());
          },
        ),
        overrides: [
          cloudVoiceServicesProvider.overrideWith((ref) async => services),
          voxtralVoiceCatalogProvider.overrideWith(
            (ref, provider) async => (loadCatalog ?? () => catalog)(),
          ),
          cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          ttsAudioPlayerProvider.overrideWithValue(player),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  testWidgets('without a cloud read-aloud model it points to the profile '
      'slot instead of listing voices', (tester) async {
    await pump(tester);

    expect(find.text('Cloud voices'), findsOneWidget);
    expect(
      find.textContaining('choose a read-aloud model in an inference profile'),
      findsOneWidget,
    );
    expect(find.byType(CloudVoicePreviewButton), findsNothing);
  });

  testWidgets("the user's language comes first, naming its voice and how "
      'many there are; the rest wait behind one row', (tester) async {
    await pump(tester, services: services);

    expect(find.text('English'), findsOneWidget);
    expect(rich('Ada · 2 voices'), findsOneWidget);
    expect(find.text('German'), findsNothing);
    expect(find.text('Catalan'), findsNothing);
    // Closed, the header says whether opening is worth it.
    expect(find.text('1 has a choice of voices'), findsOneWidget);

    await tester.tap(find.text('Other languages (3)'));
    await tester.pumpAndSettle();
    // Sorted by name, below the disclosure, which stays at the seam; a
    // language with one voice says so.
    expect(rich('Núria'), findsOneWidget);
    expect(find.textContaining('Only voice', findRichText: true), findsNothing);
    expect(rich('Amélie · 2 voices'), findsOneWidget);
    final y = tester.getTopLeft;
    // The seam row still names the group; the open list closes from its end.
    final seam = find.text('Other languages (3)');
    final fewer = find.text('Fewer languages');
    expect(seam, findsOneWidget);
    expect(fewer, findsOneWidget);
    expect(y(seam).dy, greaterThan(y(find.text('English')).dy));
    expect(y(find.text('Catalan')).dy, greaterThan(y(seam).dy));
    expect(y(find.text('German')).dy, greaterThan(y(find.text('Catalan')).dy));
    expect(y(fewer).dy, greaterThan(y(find.text('German')).dy));

    // Either one collapses.
    await tester.tap(fewer);
    await tester.pumpAndSettle();
    expect(find.text('German'), findsNothing);
    expect(find.text('Fewer languages'), findsNothing);
    await tester.tap(seam);
    await tester.pumpAndSettle();
    await tester.tap(seam);
    await tester.pumpAndSettle();
    expect(find.text('German'), findsNothing);
  });

  testWidgets("a language with a stored pick joins the user's languages, "
      'marked as their pick', (tester) async {
    storePicks({'fr': 'v-fr-2'});
    await pump(tester, services: services);
    await tester.pumpAndSettle();

    expect(find.text('French'), findsOneWidget);
    expect(rich('Damien · Your pick · 2 voices'), findsOneWidget);
    expect(find.text('Other languages (2)'), findsOneWidget);
  });

  testWidgets('a voice picked from the open page leaves its row in place '
      'until the list is collapsed', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
    await pump(tester, services: services);
    await tester.tap(find.text('Other languages (3)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    expect(find.text('French voice'), findsOneWidget);
    container
        .read(ttsSettingsControllerProvider.notifier)
        .setCloudVoice('fr', 'v-fr-2');
    Navigator.of(tester.element(find.text('French voice'))).pop();
    await tester.pumpAndSettle();

    // Still among the other languages, below the disclosure.
    expect(rich('Damien · Your pick'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('French')).dy,
      greaterThan(tester.getTopLeft(find.text('Other languages (3)')).dy),
    );

    // Collapsing regroups: the pick joins the user's own languages.
    await tester.tap(find.text('Fewer languages'));
    await tester.pumpAndSettle();
    expect(find.text('French'), findsOneWidget);
    expect(find.text('Other languages (2)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('French')).dy,
      lessThan(tester.getTopLeft(find.text('Other languages (2)')).dy),
    );
  });

  testWidgets('a sheet that closes on another voice says so, and Undo '
      'restores the voice it opened with', (tester) async {
    await pump(tester, services: services);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    container
        .read(ttsSettingsControllerProvider.notifier)
        .setCloudVoice('en', 'v-en-m');
    Navigator.of(tester.element(find.text('English voice'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('English now uses Bram'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      isEmpty,
    );
  });

  testWidgets('a sheet that closes on the voice it opened with says nothing', (
    tester,
  ) async {
    await pump(tester, services: services);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('English voice'))).pop();
    await tester.pumpAndSettle();

    expect(find.textContaining('now uses'), findsNothing);
  });

  testWidgets('a one-voice row plays that voice instead of opening a list '
      'of one, and a second tap stops it', (tester) async {
    final file = MockIoFile();
    when(() => file.path).thenReturn('/tmp/sample.wav');
    when(file.existsSync).thenReturn(true);
    when(file.delete).thenAnswer((_) async => file);
    cloud = FakeCloudSpeechSynthesizer(output: file);
    addTearDown(player.dispose);
    await pump(tester, services: services);
    await tester.tap(find.text('Other languages (3)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('German'));
    await tester.pump();

    expect(find.byType(CloudVoicePicker), findsNothing);
    expect(cloud.calls.single.route.voiceId, 'v-de');
    expect(cloud.calls.single.route.languageCode, 'de');
    expect(
      cloud.calls.single.text,
      'Hallo! So klinge ich, wenn ich dir deine Zusammenfassungen vorlese.',
    );
    await tester.pump();
    expect(player.playCount, 1);

    await tester.tap(find.text('German'));
    await tester.pump();
    expect(player.stopCount, 1);
    expect(cloud.calls, hasLength(1));
  });

  testWidgets("with none of the user's languages in the catalog every "
      'language shows, without a disclosure row', (tester) async {
    final german = VoxtralVoiceCatalog(
      fetchedAt: catalog.fetchedAt,
      voices: const [
        VoxtralVoice(id: 'v-de', name: 'Heidi', languages: ['de']),
        VoxtralVoice(id: 'v-ca', name: 'Núria', languages: ['ca']),
      ],
    );
    await pump(tester, services: services, loadCatalog: () => german);

    expect(find.text('German'), findsOneWidget);
    expect(find.text('Catalan'), findsOneWidget);
    expect(find.textContaining('Other languages'), findsNothing);
  });

  testWidgets("the row's speaker plays the voice in use on that provider, "
      'and a failure surfaces', (tester) async {
    await pump(tester, services: services);

    await tester.tap(find.byType(CloudVoicePreviewButton));
    await tester.pump();

    final call = cloud.calls.single;
    expect(
      call.text,
      'Hello! This is how I sound reading your summaries aloud.',
    );
    expect(call.route.languageCode, 'en');
    expect(call.route.voiceId, 'v-en-f');
    expect(call.route.provider, mistral);
    expect(call.route.model, voiceModel);
    // The fake fails the synthesis: this row's failure surfaces as a toast.
    await tester.pump();
    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('a tap on the row opens the picker for that language', (
    tester,
  ) async {
    await pump(tester, services: services);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('English voice'), findsOneWidget);
    expect(find.byType(CloudVoicePicker), findsOneWidget);
    expect(cloud.calls, isEmpty);
  });

  testWidgets('a catalog that cannot load says so and can be retried', (
    tester,
  ) async {
    var loads = 0;
    await pump(
      tester,
      services: services,
      loadCatalog: () {
        loads++;
        if (loads == 1) throw StateError('offline');
        return catalog;
      },
    );

    expect(
      find.textContaining('The voices could not be loaded'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(loads, 2);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('a loading catalog shows a labelled spinner', (tester) async {
    final pending = Completer<VoxtralVoiceCatalog>();
    await pump(tester, services: services, loadCatalog: () => pending.future);

    final spinner = tester.widget<DesignSystemSpinner>(
      find.byType(DesignSystemSpinner),
    );
    expect(spinner.semanticsLabel, 'Loading voices');
    pending.complete(catalog);
    await tester.pump();
    await tester.pump();
    expect(find.byType(DesignSystemSpinner), findsNothing);
  });

  testWidgets('several providers are told apart by name', (tester) async {
    final second = testInferenceProvider(
      id: 'mistral-2',
      inferenceProviderType: InferenceProviderType.mistral,
    ).copyWith(name: 'Mistral (work)');
    await pump(
      tester,
      services: [
        ...services,
        (provider: second, model: voiceModel),
      ],
    );

    expect(find.text(mistral.name), findsOneWidget);
    expect(find.text('Mistral (work)'), findsOneWidget);
  });

  testWidgets('a single provider needs no name above its rows', (
    tester,
  ) async {
    await pump(tester, services: services);
    expect(find.text(mistral.name), findsNothing);
  });
}
