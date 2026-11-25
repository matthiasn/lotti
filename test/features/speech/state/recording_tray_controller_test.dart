import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';

void main() {
  late ProviderContainer container;
  RecordingTrayController tray() =>
      container.read(recordingTrayControllerProvider.notifier);
  RecordingTrayState state() => container.read(recordingTrayControllerProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts folded, with no failure', () {
    expect(state(), (open: false, failure: null));
  });

  test('open opens it with no failure card', () {
    tray().open();
    expect(state(), (open: true, failure: null));
  });

  test('openWithFailure opens it on that failure', () {
    tray().openWithFailure(InlineRecordingFailure.recorderBusy);
    expect(state(), (open: true, failure: InlineRecordingFailure.recorderBusy));
  });

  test('open over a failure card clears the card', () {
    tray()
      ..openWithFailure(InlineRecordingFailure.microphoneDenied)
      ..open();
    expect(state(), (open: true, failure: null));
  });

  test('fold closes it and forgets the failure', () {
    tray()
      ..openWithFailure(InlineRecordingFailure.startFailed)
      ..fold();
    expect(state(), (open: false, failure: null));
  });

  test('toggle opens a folded tray and folds an open one', () {
    tray().toggle();
    expect(state().open, isTrue);
    tray().toggle();
    expect(state().open, isFalse);
  });
}
