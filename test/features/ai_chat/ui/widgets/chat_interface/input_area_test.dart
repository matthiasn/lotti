import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/input_area.dart';

void main() {
  Widget wrap(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('InputArea sends message when send tapped', (tester) async {
    String? sent;
    final controller = TextEditingController(text: 'hello');
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: controller,
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (msg) => sent = msg,
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    await tester.pumpAndSettle();
    // Tap the send button (IconButton.filled with send icon since there is text)
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(sent, 'hello');
  });

  testWidgets('InputArea shows mic when empty and not requiresModelSelection',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        InputArea(
          controller: TextEditingController(),
          scrollController: ScrollController(),
          isLoading: false,
          canSend: true,
          requiresModelSelection: false,
          categoryId: 'cat',
          onSendMessage: (_) {},
        ),
        overrides: [
          chatRecorderControllerProvider
              .overrideWith(ChatRecorderController.new),
        ],
      ),
    );

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
