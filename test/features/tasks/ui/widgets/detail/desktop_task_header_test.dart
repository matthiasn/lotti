import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';

import '../../../../../widget_test_utils.dart';
import 'detail_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpDetailTestGetIt);
  tearDown(tearDownDetailTestGetIt);

  Widget buildSubject() {
    return makeTestableWidgetWithScaffold(
      SizedBox(
        width: 600,
        child: DesktopTaskHeader(taskId: detailTestTask.meta.id),
      ),
      theme: DesignSystemTheme.dark(),
      overrides: [createDetailEntryOverride(detailTestTask)],
    );
  }

  testWidgets('displays task title', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Test detail task'), findsOneWidget);
  });

  testWidgets('displays priority short label and glyph', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text(detailTestTask.data.priority.short), findsOneWidget);
    expect(find.byType(TaskShowcasePriorityGlyph), findsOneWidget);
  });

  testWidgets('displays standalone more-vert menu icon', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
  });

  testWidgets('displays status label in metadata row', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(TaskShowcaseStatusLabel), findsOneWidget);
    expect(find.byType(TaskShowcaseStatusGlyph), findsOneWidget);
  });

  testWidgets('displays category chip with name', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(TaskShowcaseCategoryChip), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('displays due date chip', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(TaskShowcaseMetaChip), findsOneWidget);
    expect(find.byIcon(Icons.watch_later_outlined), findsOneWidget);
  });

  testWidgets('displays label chips', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(TaskShowcaseLabelChip), findsOneWidget);
    expect(find.text('Bug fix'), findsOneWidget);
  });

  testWidgets('tapping title enables editing mode', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Test detail task'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });
}
