import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/transcript_editor.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('renders transcript inside a calm content-height editor panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: TranscriptEditor(
          fieldKey: const Key('transcript-editor-field'),
          transcript: 'Review this captured sentence.',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Review this captured sentence.'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('transcript-editor-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.minLines, 4);
    expect(field.maxLines, isNull);
    expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());
    expect(field.decoration?.border, InputBorder.none);
    expect(field.decoration?.enabledBorder, InputBorder.none);
    expect(field.decoration?.focusedBorder, InputBorder.none);
  });

  testWidgets('uses the provided line count as the editable field minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: TranscriptEditor(
          fieldKey: const Key('transcript-editor-field'),
          transcript: 'Initial text',
          lineCount: 6,
          onChanged: (_) {},
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('transcript-editor-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.minLines, 6);
    expect(field.maxLines, isNull);
  });

  testWidgets('passes edited transcript text to onChanged', (tester) async {
    var latest = '';

    await tester.pumpWidget(
      WidgetTestBench(
        child: TranscriptEditor(
          fieldKey: const Key('transcript-editor-field'),
          transcript: 'Initial text',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('transcript-editor-field')),
      'Edited transcript',
    );

    expect(latest, 'Edited transcript');
  });
}
