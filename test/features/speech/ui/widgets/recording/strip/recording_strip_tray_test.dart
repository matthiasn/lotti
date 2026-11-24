import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_tray.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../relationships/helpers/check_in_speech_fakes.dart';
import 'strip_test_bench.dart';

/// A recorder whose take its caller transcribes itself.
class _CallerTranscribes extends FakeAudioRecorderController {
  @override
  bool get transcriptionHandledByCaller => true;
}

void main() {
  late StripBench bench;

  setUp(() => bench = StripBench());
  tearDown(() => bench.dispose());

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(RecordingStripTray)),
  );

  Future<void> pump(
    WidgetTester tester, {
    AutomaticPromptVisibility visibility = const AutomaticPromptVisibility(
      speech: true,
    ),
    bool take = true,
  }) async {
    await bench.pump(
      tester,
      const SizedBox(width: 390, child: RecordingStripTray()),
      extra: [
        checkboxVisibilityProvider((
          categoryId: 'category-7',
          linkedId: stripSubjectId,
        )).overrideWithValue(visibility),
      ],
    );
    bench.recorder.setCategoryId('category-7');
    if (take) await bench.startTake(tester);
  }

  Finder key(Key key) => find.byKey(key);

  /// Pumps a confirmation modal's transition through, frame by frame.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets("over a take it is the full recorder under the strip's own "
      'leading part', (tester) async {
    await pump(tester);

    expect(find.byType(RecordingStripLeading), findsOneWidget);
    expect(find.byType(RecordingStage), findsOneWidget);
    expect(key(RecordingTransportControls.discardKey), findsOneWidget);
    expect(key(RecordingTransportControls.stopKey), findsOneWidget);
    expect(key(RecordingTransportControls.pauseKey), findsOneWidget);
    expect(find.byType(RecordingFailureCallout), findsNothing);
  });

  testWidgets('the grabber folds it, and is named for it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    container(tester).read(recordingTrayControllerProvider.notifier).open();

    expect(
      tester.getSemantics(key(RecordingStripTray.grabberKey)).label,
      'Fold recorder',
    );
    await tester.tap(key(RecordingStripTray.grabberKey));
    expect(
      container(tester).read(recordingTrayControllerProvider).open,
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('a swipe down folds it; a swipe up does not', (tester) async {
    await pump(tester);
    final tray = container(
      tester,
    ).read(recordingTrayControllerProvider.notifier)..open();

    await tester.fling(
      key(RecordingStripTray.trayKey),
      const Offset(0, -80),
      800,
    );
    await tester.pump();
    expect(
      container(tester).read(recordingTrayControllerProvider).open,
      isTrue,
    );

    await tester.fling(
      key(RecordingStripTray.trayKey),
      const Offset(0, 80),
      800,
    );
    await tester.pump();
    expect(
      container(tester).read(recordingTrayControllerProvider).open,
      isFalse,
    );
    tray.fold();
  });

  testWidgets('pause toggles the take', (tester) async {
    await pump(tester);
    await tester.tap(key(RecordingTransportControls.pauseKey));
    await tester.pump();
    expect(bench.recorder.pauseCalls, 1);
    await tester.tap(key(RecordingTransportControls.pauseKey));
    await tester.pump();
    expect(bench.recorder.resumeCalls, 1);
  });

  testWidgets('Stop saves the take and puts up its receipt', (tester) async {
    await pump(tester);
    await tester.tap(key(RecordingTransportControls.stopKey));
    await tester.pump();
    await tester.pump();

    expect(bench.recorder.stopDeferrals, [true]);
    final receipts = container(tester).read(
      recordingReceiptControllerProvider.notifier,
    );
    expect(
      container(tester).read(recordingReceiptControllerProvider),
      isNotNull,
    );
    receipts.commit();
  });

  group('discard', () {
    testWidgets('asks first; confirming throws the take away', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(key(RecordingTransportControls.discardKey));
      await settle(tester);
      expect(find.text('Discard recording?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(bench.recorder.cancelCalls, 1);
    });

    testWidgets('backing out keeps recording', (tester) async {
      await pump(tester);
      await tester.tap(key(RecordingTransportControls.discardKey));
      await settle(tester);

      await tester.tap(find.text('Keep recording'));
      await settle(tester);
      expect(bench.recorder.cancelCalls, 0);
    });
  });

  group('Transcribe', () {
    testWidgets("shows the take's choice and changes it", (tester) async {
      await pump(tester);
      expect(key(RecordingStripTray.transcribeKey), findsOneWidget);

      await tester.tap(key(RecordingStripTray.transcribeKey));
      await tester.pump();
      expect(
        container(
          tester,
        ).read(audioRecorderControllerProvider).enableSpeechRecognition,
        isFalse,
      );
    });

    testWidgets('is left out where the category and subject have no '
        'automation', (tester) async {
      await pump(
        tester,
        visibility: const AutomaticPromptVisibility(speech: false),
      );
      expect(key(RecordingStripTray.transcribeKey), findsNothing);
    });

    testWidgets('is left out for a take its caller transcribes itself', (
      tester,
    ) async {
      bench.dispose();
      bench = StripBench(recorder: _CallerTranscribes());
      await pump(tester);
      expect(key(RecordingStripTray.transcribeKey), findsNothing);
    });

    testWidgets('is left out for a voice note filed nowhere', (tester) async {
      await pump(tester, take: false);
      bench.recorder.setCategoryId(null);
      await bench.startTake(tester, voiceNote: true);
      expect(key(RecordingStripTray.transcribeKey), findsNothing);
    });
  });

  group('opened for a failed start', () {
    Future<void> openOn(
      WidgetTester tester,
      InlineRecordingFailure failure, {
      bool take = false,
    }) async {
      await pump(tester, take: take);
      container(
        tester,
      ).read(recordingTrayControllerProvider.notifier).openWithFailure(failure);
      await tester.pump();
    }

    testWidgets('a refused microphone shows its card, alone, with Open '
        'settings', (tester) async {
      await openOn(tester, InlineRecordingFailure.microphoneDenied);

      expect(
        key(const ValueKey('recording-failure-microphoneDenied')),
        findsOneWidget,
      );
      expect(find.byType(RecordingStage), findsNothing);
      expect(find.byType(RecordingStripLeading), findsNothing);

      await tester.tap(key(RecordingFailureCallout.openSettingsKey));
      await tester.pump();
      expect(bench.settingsOpened, 1);
    });

    testWidgets('a take held elsewhere: Stop that recording saves that take '
        'and puts up its receipt', (tester) async {
      await openOn(
        tester,
        InlineRecordingFailure.recorderBusy,
        take: true,
      );
      expect(find.byType(RecordingStage), findsOneWidget);

      await tester.tap(key(RecordingFailureCallout.stopRunningKey));
      await tester.pump();
      await tester.pump();
      expect(bench.recorder.stopCalls, 1);
      expect(
        container(tester).read(recordingReceiptControllerProvider),
        isNotNull,
      );
      expect(
        container(tester).read(recordingTrayControllerProvider).open,
        isFalse,
      );
      container(
        tester,
      ).read(recordingReceiptControllerProvider.notifier).commit();
    });

    testWidgets('a start that failed shows its card', (tester) async {
      await openOn(tester, InlineRecordingFailure.startFailed);
      expect(
        key(const ValueKey('recording-failure-startFailed')),
        findsOneWidget,
      );
    });
  });

  testWidgets('a second Stop while the first saves does nothing', (
    tester,
  ) async {
    await pump(tester);
    bench.recorder.stopGate = Completer<void>();
    await tester.tap(key(RecordingTransportControls.stopKey));
    await tester.pump();
    await tester.tap(key(RecordingTransportControls.stopKey));
    await tester.pump();
    expect(bench.recorder.stopCalls, 1);

    bench.recorder.stopGate!.complete();
    await tester.pump();
    await tester.pump();
    container(
      tester,
    ).read(recordingReceiptControllerProvider.notifier).commit();
  });
}
