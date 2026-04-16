import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_bubble.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_timestamp.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget wrap(Widget child) => makeTestableWidgetWithScaffold(
    Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );

  group('MessageBubble', () {
    testWidgets('renders user and assistant content', (tester) async {
      final user = ChatMessage.user('User says');
      final ai = ChatMessage.assistant('Assistant replies');

      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              MessageBubble(message: user),
              MessageBubble(message: ai),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('User says'), findsOneWidget);
      expect(find.text('Assistant replies'), findsOneWidget);
    });

    testWidgets('hides timestamp for pure thinking messages', (tester) async {
      final thinkingOnly = ChatMessage.assistant('<thinking>plan</thinking>');
      await tester.pumpWidget(wrap(MessageBubble(message: thinkingOnly)));
      await tester.pumpAndSettle();

      // Timestamp widget should not be rendered for thinking-only messages
      expect(find.byType(MessageTimestamp), findsNothing);
    });

    testWidgets('shows copy action for assistant visible content', (
      tester,
    ) async {
      final ai = ChatMessage.assistant('Visible content');
      await tester.pumpWidget(wrap(MessageBubble(message: ai)));
      await tester.pumpAndSettle();

      // Tap the copy corner action (tooltip 'Copy')
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      // We don't assert the SnackBar (theme-dependent). The tap should not throw.
    });

    testWidgets('copy action writes clipboard and shows a toast', (
      tester,
    ) async {
      var clipboardText = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = (args['text'] as String?) ?? '';
          }
          return null;
        },
      );
      // Register cleanup before any tap/assertion so a failure cannot leak
      // the mock handler into later tests.
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final ai = ChatMessage.assistant(
        'Visible answer <thinking>hidden plan</thinking> trailing',
      );
      await tester.pumpWidget(wrap(MessageBubble(message: ai)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Thinking content must be stripped from what's copied to the clipboard.
      expect(clipboardText.contains('Visible answer'), isTrue);
      expect(clipboardText.contains('trailing'), isTrue);
      expect(clipboardText.contains('hidden plan'), isFalse);

      // Success toast appears via the design-system toast extension.
      expect(find.byType(DesignSystemToast), findsOneWidget);
      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.success);
    });
  });
}
