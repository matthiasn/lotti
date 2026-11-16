import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import '../../companion_overrides.dart';

/// She ticks for as long as she is mounted: pump frames, never settle —
/// past the quarter second a change waits before it is sent.
Future<void> pumpCompanionFrames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The voice as her settings see it: what it was asked to speak, and what
/// it was asked to stop.
class RecordingVoice extends TtsPlaybackController {
  final spoken = <({String sourceId, String text})>[];
  final stopped = <String?>[];

  /// How the last utterance asked before downloading the voice model.
  TtsModelDownloadConsent? confirmModelDownload;

  @override
  TtsPlaybackState build() => const TtsPlaybackState();

  @override
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = 'en',
    Future<bool> Function()? canPlay,
    TtsModelDownloadConsent? confirmModelDownload,
    TtsCloudRoute? cloudRoute,
  }) async {
    spoken.add((sourceId: sourceId, text: text));
    this.confirmModelDownload = confirmModelDownload;
    state = TtsPlaybackState(
      status: TtsPlaybackStatus.playing,
      sourceId: sourceId,
    );
  }

  @override
  Future<void> stop({String? sourceId}) async {
    stopped.add(sourceId);
    state = const TtsPlaybackState();
  }
}

/// Pumps her settings at [size], bounded as the app hosts them, on [tab].
///
/// Her outfit is pinned — or, on [surprise], drawn for the session from a
/// fixed seed — her choices are stored in [db], read-aloud is on or
/// off ([readAloud]) with an on-device voice that is [engineSupported] or
/// not, no profile reads aloud with a cloud voice, and [voice] stands in
/// for the app's.
Future<void> pumpCompanionSettings(
  WidgetTester tester, {
  required SettingsDb db,
  required OutboxService outbox,
  CompanionCustomization customization = const CompanionCustomization(),
  Size size = const Size(800, 1600),
  bool readAloud = false,
  bool engineSupported = true,
  bool surprise = false,
  RecordingVoice? voice,
  CompanionSettingsTab tab = CompanionSettingsTab.look,
  List<Override> overrides = const [],
  Widget child = const Scaffold(body: CompanionSettingsBody()),
}) async {
  setTestSurfaceSize(tester, size);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      child,
      overrides: [
        configFlagProvider(
          enableAiSummaryTtsFlag,
        ).overrideWith((ref) => Stream.value(readAloud)),
        settingsDbProvider.overrideWithValue(db),
        outboxServiceProvider.overrideWithValue(outbox),
        ttsEngineProvider.overrideWithValue(
          FakeTtsEngine(supported: engineSupported),
        ),
        ttsPlaybackControllerProvider.overrideWith(
          () => voice ?? RecordingVoice(),
        ),
        cloudVoiceServicesProvider.overrideWith((ref) async => const []),
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
        ...overrides,
      ],
    ),
  );
  await pumpCompanionFrames(tester);
  await openCompanionSettingsTab(tester, tab);
}

/// Opens [tab], scrolled into view first: in the test font the tabs are
/// wider than a narrow pane and scroll.
Future<void> openCompanionSettingsTab(
  WidgetTester tester,
  CompanionSettingsTab tab,
) async {
  final finder = find.byKey(CompanionSettingsKeys.tab(tab));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await pumpCompanionFrames(tester);
}
