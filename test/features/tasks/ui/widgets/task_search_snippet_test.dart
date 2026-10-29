import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task_search_hit.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_type_icon.dart';
import 'package:lotti/features/tasks/ui/widgets/task_search_snippet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpSnippet(WidgetTester tester, TaskSearchHit hit) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(TaskSearchSnippet(hit: hit)),
    );
    await tester.pump();
  }

  testWidgets('the matched words stand out from the words around them', (
    tester,
  ) async {
    await pumpSnippet(
      tester,
      const TaskSearchHit(
        taskId: 't',
        snippet: '…refill the \uE000krill\uE001 tubs',
        matchedType: 'Task',
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((span) => span.text), ['…refill the ', 'krill', ' tubs']);
    final tokens = tester.element(find.byType(Text)).designTokens;
    expect(spans[0].style, isNull, reason: 'the snippet style applies');
    expect(spans[1].style?.color, tokens.colors.text.highEmphasis);
    expect(spans[1].style?.fontWeight, tokens.typography.weight.semiBold);
    expect(text.maxLines, 2);
  });

  testWidgets('leads with the glyph of what matched', (tester) async {
    for (final type in ['Task', 'ChecklistItem', 'JournalAudio']) {
      await pumpSnippet(
        tester,
        TaskSearchHit(taskId: 't', snippet: 'x', matchedType: type),
      );

      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        entryTypeIcon(type),
        reason: type,
      );
    }
  });
}
