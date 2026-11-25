import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/chrome/sidebar_audio_recording_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/widgets/misc/sidebar_live_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/relationships/helpers/check_in_speech_fakes.dart';
import '../../features/speech/ui/widgets/recording/strip/strip_test_bench.dart';
import '../../widget_test_utils.dart';

/// A recorder whose audio stack failed to load.
class _BrokenRecorder extends FakeAudioRecorderController {
  @override
  AudioRecorderState build() => throw StateError('no audio stack');
}

void main() {
  late StripBench bench;

  setUp(() => bench = StripBench());
  tearDown(() => bench.dispose());

  Future<void> pump(WidgetTester tester, {StripBench? on}) =>
      (on ?? bench).pump(
        tester,
        const SizedBox(width: 280, child: SidebarAudioRecordingSection()),
        mediaQueryData: desktopLayoutMediaQueryData,
      );

  Finder card() => find.byKey(SidebarAudioRecordingSection.cardKey);
  SidebarLiveCard liveCard(WidgetTester tester) =>
      tester.widget<SidebarLiveCard>(card());
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(SidebarAudioRecordingSection)),
      );

  testWidgets('shows nothing while nothing records', (tester) async {
    await pump(tester);
    expect(card(), findsNothing);
  });

  testWidgets("a running take: the subject's title, the running time, the "
      'mic with its pulse, all in the alert red', (tester) async {
    await pump(tester);
    await bench.startTake(tester);
    bench.recorder.tick(progress: const Duration(seconds: 7));
    await tester.pump();
    await tester.pump(SidebarAudioRecordingSection.animationDuration);

    final live = liveCard(tester);
    expect(live.title, stripSubject.data.title);
    expect(live.timeText, '00:00:07');
    expect(live.glyph, LottiIcons.mic);
    expect(live.pulse, isTrue);
    expect(live.statusLabel, 'Recording');
    expect(
      live.accent,
      tester.element(card()).designTokens.colors.alert.error.defaultColor,
    );
  });

  testWidgets('a paused take stays on the card, still and called Paused, '
      'never announced as recording', (tester) async {
    await pump(tester);
    await bench.startTake(tester);
    await bench.recorder.pause();
    await tester.pump();
    final live = liveCard(tester);
    expect(live.pulse, isFalse);
    expect(live.statusLabel, 'Paused');
    expect(live.semanticsLabel, 'Paused');
  });

  testWidgets('a recording take pulses and is announced as recording', (
    tester,
  ) async {
    await pump(tester);
    await bench.startTake(tester);
    expect(liveCard(tester).semanticsLabel, 'Audio recording in progress');
  });

  testWidgets("a take whose task's page is on screen has no card: its "
      'action bar carries it', (tester) async {
    await pump(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(SidebarAudioRecordingSection)),
    ).read(recordingHomesProvider.notifier).enter(stripSubjectId);
    await bench.startTake(tester);
    await tester.pump(SidebarAudioRecordingSection.animationDuration);
    expect(card(), findsNothing);
  });

  testWidgets('a take a check-in draws in place has no card', (
    tester,
  ) async {
    await pump(tester);
    await bench.startTake(tester);
    bench.recorder.setInlineHostVisible(visible: true);
    await tester.pump();
    await tester.pump(SidebarAudioRecordingSection.animationDuration);
    await tester.pump(SidebarAudioRecordingSection.animationDuration);
    expect(card(), findsNothing);
  });

  testWidgets('a take linked to nothing is a voice note', (tester) async {
    await pump(tester);
    await bench.startTake(tester, voiceNote: true);
    expect(liveCard(tester).title, 'Voice note');
  });

  testWidgets('a tap on the card takes the user back to where the take '
      'started', (tester) async {
    await pump(tester);
    await bench.startTake(tester);
    await tester.pump(SidebarAudioRecordingSection.animationDuration);

    await tester.tap(find.text(stripSubject.data.title));
    await tester.pump();
    verify(() => bench.nav.beamToNamed(stripSubjectRoute)).called(1);
  });

  testWidgets('a take with no origin has no way back: the card is not a '
      'button', (tester) async {
    await pump(tester);
    await bench.recorder.record(linkedId: stripSubjectId);
    await tester.pump();
    await tester.pump();
    expect(liveCard(tester).onTap, isNull);
  });

  testWidgets('Stop saves the take and puts up its receipt', (tester) async {
    await pump(tester);
    await bench.startTake(tester);
    await tester.pump(SidebarAudioRecordingSection.animationDuration);

    await tester.tap(find.byKey(SidebarAudioRecordingSection.stopKey));
    await tester.pump();
    await tester.pump();

    expect(bench.recorder.stopDeferrals, [true]);
    final container = containerOf(tester);
    expect(
      container.read(recordingReceiptControllerProvider)?.entryId,
      'audio-1',
    );
    container.read(recordingReceiptControllerProvider.notifier).commit();
    // The stopped take's card fades out, then leaves.
    await tester.pump(SidebarAudioRecordingSection.animationDuration);
    await tester.pump(SidebarAudioRecordingSection.animationDuration);
    expect(card(), findsNothing);
  });

  testWidgets('a recorder that cannot be built shows nothing rather than '
      'taking the sidebar down', (tester) async {
    final broken = StripBench(recorder: _BrokenRecorder());
    addTearDown(broken.dispose);
    await pump(tester, on: broken);
    expect(card(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
