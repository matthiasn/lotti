import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

class _FakeRecorderController extends ChatRecorderController {
  _FakeRecorderController(super.ref);

  @override
  List<double> getNormalizedAmplitudeHistory() => const [0.2, 0.6, 0.9];
}

void main() {
  testWidgets('renders waveform with controller amplitudes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(_FakeRecorderController.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatVoiceControls(
              onCancel: _noop,
              onStop: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('waveform_bars')), findsOneWidget);

    final wb = tester.widget<WaveformBars>(find.byType(WaveformBars));
    expect(wb.amplitudesNormalized, equals(const [0.2, 0.6, 0.9]));
  });

  testWidgets('tapping Cancel and Stop trigger callbacks', (tester) async {
    var cancelCalled = false;
    var stopCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(_FakeRecorderController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatVoiceControls(
              onCancel: () => cancelCalled = true,
              onStop: () => stopCalled = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(cancelCalled, isTrue);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    expect(stopCalled, isTrue);
  });

  testWidgets('ESC key triggers onCancel shortcut', (tester) async {
    var cancelCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(_FakeRecorderController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatVoiceControls(
              onCancel: () => cancelCalled = true,
              onStop: _noop,
            ),
          ),
        ),
      ),
    );

    // Widget requests autofocus. Send ESC.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(cancelCalled, isTrue);
  });
}

void _noop() {}
