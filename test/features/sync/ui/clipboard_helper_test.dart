import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';

import '../../../widget_test_utils.dart';

Future<void> _pumpCopyButton(
  WidgetTester tester,
  VoidCallback Function(BuildContext) onPressed,
) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: onPressed(context),
          child: const Text('Copy'),
        ),
      ),
    ),
  );
}

void main() {
  group('ClipboardHelper.copyTextAndNotify', () {
    testWidgets(
      'writes text to the system clipboard and shows a DesignSystemToast',
      (tester) async {
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

        await _pumpCopyButton(
          tester,
          (context) =>
              () => ClipboardHelper.copyTextAndNotify(
                context,
                'Hello World',
                title: 'Copied to clipboard',
              ),
        );

        await tester.tap(find.text('Copy'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(clipboardText, 'Hello World');
        expect(find.byType(DesignSystemToast), findsOneWidget);
        expect(find.text('Copied to clipboard'), findsOneWidget);
      },
    );

    testWidgets('honors tone, description, and duration', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => null,
      );

      await _pumpCopyButton(
        tester,
        (context) =>
            () => ClipboardHelper.copyTextAndNotify(
              context,
              'x',
              title: 'Diagnostics copied',
              description: 'Paste into a bug report',
              tone: DesignSystemToastTone.warning,
              duration: const Duration(seconds: 2),
            ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.warning);
      expect(toast.title, 'Diagnostics copied');
      expect(toast.description, 'Paste into a bug report');

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 2));
    });

    testWidgets('default tone is success and description is omitted', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => null,
      );

      await _pumpCopyButton(
        tester,
        (context) =>
            () => ClipboardHelper.copyTextAndNotify(
              context,
              'x',
              title: 'Copied',
            ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.success);
      expect(toast.description, isNull);
    });

    testWidgets(
      'rethrows and shows no toast when the clipboard channel fails',
      (tester) async {
        // Simulate an unavailable / failing platform clipboard: the channel
        // throws, so Clipboard.setData rejects. The helper does not swallow
        // this, so the future must reject and no toast may appear.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'clipboard_unavailable');
            }
            return null;
          },
        );

        late BuildContext capturedContext;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await expectLater(
          ClipboardHelper.copyTextAndNotify(
            capturedContext,
            'unreachable',
            title: 'Copied',
          ),
          throwsA(isA<PlatformException>()),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The failure short-circuits before context.showToast, so nothing
        // renders.
        expect(find.byType(DesignSystemToast), findsNothing);
      },
    );
  });
}
