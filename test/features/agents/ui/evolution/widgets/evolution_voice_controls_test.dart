import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_voice_controls.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import 'evolution_recorder_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required VoidCallback onCancel,
    required VoidCallback onStop,
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionVoiceControls(onCancel: onCancel, onStop: onStop),
      overrides: [
        chatRecorderControllerProvider.overrideWith(
          RecordingTestController.new,
        ),
        ...overrides,
      ],
    );
  }

  testWidgets('shows waveform, cancel, and stop buttons', (tester) async {
    await tester.pumpWidget(
      buildSubject(onCancel: () {}, onStop: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('evolution_waveform')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);
  });

  testWidgets('cancel button invokes onCancel', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      buildSubject(
        onCancel: () => cancelled = true,
        onStop: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets('stop button invokes onStop', (tester) async {
    var stopped = false;
    await tester.pumpWidget(
      buildSubject(
        onCancel: () {},
        onStop: () => stopped = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    expect(stopped, isTrue);
  });

  testWidgets('has correct tooltips', (tester) async {
    await tester.pumpWidget(
      buildSubject(onCancel: () {}, onStop: () {}),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EvolutionVoiceControls));
    expect(
      find.byTooltip(context.messages.chatInputCancelRecording),
      findsOneWidget,
    );
    expect(
      find.byTooltip(context.messages.chatInputStopTranscribe),
      findsOneWidget,
    );
  });
}
