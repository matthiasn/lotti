import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_description_card.dart';

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
        child: DesktopDescriptionCard(taskId: detailTestTask.meta.id),
      ),
      theme: DesignSystemTheme.dark(),
      overrides: [createDetailEntryOverride(detailTestTask)],
    );
  }

  testWidgets('displays Task description title', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Task description'), findsOneWidget);
  });

  testWidgets('displays collapse toggle icon', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
  });

  testWidgets('collapses and expands on toggle', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
  });
}
