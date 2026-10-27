import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voices_section.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';

import '../../../../mocks/mocks.dart' show MockDomainLogger;
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
  final catalog = VoxtralVoiceCatalog(
    fetchedAt: DateTime.utc(2026, 10, 27),
    voices: const [
      VoxtralVoice(
        id: 'v-de-m',
        name: 'Klaus',
        gender: 'male',
        languages: ['de'],
        type: VoxtralVoiceType.preset,
      ),
      VoxtralVoice(
        id: 'v-de-f',
        name: 'Heidi',
        gender: 'female',
        languages: ['German'],
        type: VoxtralVoiceType.preset,
      ),
      // A language the app ships no catalog for: no sample to test with.
      VoxtralVoice(id: 'v-hi', name: 'Asha', languages: ['hi']),
    ],
  );

  late FakeCloudSpeechSynthesizer cloud;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestGetIt();
    cloud = FakeCloudSpeechSynthesizer();
  });
  tearDown(tearDownTestGetIt);

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
            return const TtsCloudVoicesSection();
          },
        ),
        overrides: [
          cloudVoiceServicesProvider.overrideWith((ref) async => services),
          voxtralVoiceCatalogProvider.overrideWith(
            (ref, provider) async => (loadCatalog ?? () => catalog)(),
          ),
          cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  final services = <CloudVoiceService>[(provider: mistral, model: voiceModel)];

  testWidgets('without a cloud read-aloud model it points to the profile '
      'slot instead of listing voices', (tester) async {
    await pump(tester);

    expect(find.text('Cloud voices'), findsOneWidget);
    expect(
      find.textContaining('choose a read-aloud model in an inference profile'),
      findsOneWidget,
    );
    expect(find.byType(TtsPlayButton), findsNothing);
  });

  testWidgets('one row per catalog language, the female preset as the '
      'default, a test only where the app has a sample', (tester) async {
    await pump(tester, services: services);

    expect(find.textContaining('Each language uses your pick'), findsOneWidget);
    // German and Hindi rows; "German" and "de" are one language.
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Default · Heidi'), findsOneWidget);
    expect(find.text('Default · Asha'), findsOneWidget);
    // Only German has a sample sentence in a shipped catalog.
    expect(find.byType(TtsPlayButton), findsOneWidget);
    // A single provider needs no name above its rows.
    expect(find.text(mistral.name), findsNothing);
  });

  testWidgets('choosing a voice persists it per language; the default '
      'clears it', (tester) async {
    // The open panel adds its list below the field; give it the height the
    // scrolling settings page would.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
    await pump(tester, services: services);

    await tester.tap(find.text('Default · Heidi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klaus').last);
    await tester.pumpAndSettle();
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      {'de': 'v-de-m'},
    );
    expect(find.text('Klaus'), findsOneWidget);

    await tester.tap(find.text('Klaus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default · Heidi').last);
    await tester.pumpAndSettle();
    expect(
      container.read(ttsSettingsControllerProvider).cloudVoiceByLanguage,
      isEmpty,
    );
  });

  testWidgets('an open voice picker stays with its language when a '
      'refreshed catalog adds one above it', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
    var current = catalog;
    await pump(tester, services: services, loadCatalog: () => current);

    await tester.tap(find.text('Default · Heidi'));
    await tester.pumpAndSettle();
    expect(find.text('Klaus'), findsOneWidget);

    current = VoxtralVoiceCatalog(
      fetchedAt: catalog.fetchedAt,
      voices: [
        const VoxtralVoice(id: 'v-cs', name: 'Petra', languages: ['cs']),
        ...catalog.voices,
      ],
    );
    container.invalidate(voxtralVoiceCatalogProvider);
    await tester.pumpAndSettle();

    // Czech now leads, closed; the German picker is still the open one.
    expect(find.text('Default · Petra'), findsOneWidget);
    expect(find.text('Petra'), findsNothing);
    expect(find.text('Klaus'), findsOneWidget);
  });

  testWidgets("the test speaks the language's own sample on that "
      'provider', (tester) async {
    await pump(tester, services: services);

    await tester.tap(find.byType(TtsPlayButton));
    await tester.pump();

    final call = cloud.calls.single;
    expect(
      call.text,
      'Hallo! So klinge ich, wenn ich dir deine Zusammenfassungen vorlese.',
    );
    expect(call.route.languageCode, 'de');
    expect(call.route.provider, mistral);
    expect(call.route.model, voiceModel);
    // The fake fails the synthesis: this row's failure surfaces as a toast.
    await tester.pump();
    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('a catalog that cannot load says so', (tester) async {
    await pump(
      tester,
      services: services,
      loadCatalog: () => throw StateError('offline'),
    );

    expect(
      find.textContaining('The voices could not be loaded'),
      findsOneWidget,
    );
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
}
