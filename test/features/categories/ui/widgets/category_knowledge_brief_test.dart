import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_knowledge_brief.dart';
import 'package:lotti/features/categories/ui/widgets/category_knowledge_brief.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryKnowledgeBrief', () {
    testWidgets('renders empty with the hint, label in semantics only', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryKnowledgeBrief(brief: null, onChanged: (_) {}),
        ),
      );

      final textarea = tester.widget<DesignSystemTextarea>(
        find.byType(DesignSystemTextarea),
      );
      // The hosting section header names the field; no in-field label.
      expect(find.text('Category knowledge'), findsNothing);
      expect(textarea.semanticsLabel, 'Category knowledge');
      expect(textarea.maxLength, categoryKnowledgeBriefMaxLength);
      expect(textarea.growWithContent, isTrue);
      expect(
        find.text(
          'Flutter app, repository at github.com/…, run tests with make test, …',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('shows the stored brief verbatim, newlines included', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryKnowledgeBrief(
            brief: 'Flutter app\nrepo at github.com/x',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Flutter app\nrepo at github.com/x'), findsOneWidget);
    });

    testWidgets('reports every edit as typed', (tester) async {
      String? changed;
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryKnowledgeBrief(
            brief: null,
            onChanged: (value) => changed = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '  Flutter app \n');
      expect(changed, '  Flutter app \n');
    });

    testWidgets('takes an external change but never clobbers typed text', (
      tester,
    ) async {
      Widget build(String? brief) => WidgetTestBench(
        child: CategoryKnowledgeBrief(brief: brief, onChanged: (_) {}),
      );

      await tester.pumpWidget(build('one'));
      // A sync/reload with different text replaces what is shown.
      await tester.pumpWidget(build('two'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'two',
      );

      // The controller echoing the user's own keystroke back must leave the
      // field alone — the text already matches, so no reset happens.
      await tester.enterText(find.byType(TextField), 'two and more');
      await tester.pumpWidget(build('two and more'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'two and more',
      );
      // And a stale echo of the previous value does not roll typing back.
      await tester.pumpWidget(build('two and more'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'two and more',
      );
    });
  });

  group('categoryKnowledgeBriefOf', () {
    test('trims a brief and reads blank or missing as null', () {
      expect(categoryKnowledgeBriefOf(null), isNull);
      expect(
        categoryKnowledgeBriefOf(_category(null)),
        isNull,
      );
      expect(categoryKnowledgeBriefOf(_category('  \n ')), isNull);
      expect(
        categoryKnowledgeBriefOf(_category('  Flutter app\nline two \n')),
        'Flutter app\nline two',
      );
    });
  });
}

CategoryDefinition _category(String? brief) => CategoryDefinition(
  id: 'cat',
  name: 'Cat',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  vectorClock: null,
  private: false,
  active: true,
  knowledgeBrief: brief,
);
