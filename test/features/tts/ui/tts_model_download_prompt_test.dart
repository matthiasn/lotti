import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  final model = ttsModelByIdOrDefault(kDefaultTtsModelId);

  Future<Future<bool>> openPrompt(WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final answer = confirmTtsModelDownload(hostContext, model);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return answer;
  }

  testWidgets('discloses the model size before anything downloads', (
    tester,
  ) async {
    final answer = await openPrompt(tester);

    expect(find.text('Download the voice model?'), findsOneWidget);
    expect(
      find.text(
        'Reading aloud runs on this device and needs a one-time 398.4 MB '
        'download of the voice model. Wi-Fi is recommended.',
      ),
      findsOneWidget,
    );
    expect(find.text('Download (398.4 MB)'), findsOneWidget);

    await tester.tap(find.text('Download (398.4 MB)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await answer, isTrue);
  });

  testWidgets('cancelling answers no', (tester) async {
    final answer = await openPrompt(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await answer, isFalse);
    expect(find.text('Download the voice model?'), findsNothing);
  });

  testWidgets('a context that is gone answers no without asking', (
    tester,
  ) async {
    late BuildContext goneContext;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            goneContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(await confirmTtsModelDownload(goneContext, model), isFalse);
  });
}
