import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/documents/ui/task_document_copy.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('puts the markdown on the clipboard and says so', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => copyTaskDocumentMarkdown(context, '# Brief'),
            child: const Text('copy'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('copy'));
    await tester.pump();

    expect(copied, ['# Brief']);
    expect(find.text('Markdown copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
