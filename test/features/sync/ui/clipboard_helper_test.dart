import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('ClipboardHelper', () {
    testWidgets('copies text and shows snackbar', (tester) async {
      // Set up clipboard mock
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ClipboardHelper.copyTextWithSnackBar(context, 'Hello World'),
              child: const Text('Copy'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(clipboardText, 'Hello World');
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('shows custom snackbar when provided', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => null,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ClipboardHelper.copyTextWithSnackBar(
                context,
                'test',
                snackBar: const SnackBar(content: Text('Custom message')),
              ),
              child: const Text('Copy'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(find.text('Custom message'), findsOneWidget);
    });
  });
}
