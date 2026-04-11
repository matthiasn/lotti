import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_action_bar.dart';

import '../../../../../widget_test_utils.dart';
import 'detail_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpDetailTestGetIt);
  tearDown(tearDownDetailTestGetIt);

  Widget buildSubject() {
    return makeTestableWidgetNoScroll(
      Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: DesktopActionBar(taskId: detailTestTask.meta.id),
        ),
      ),
      theme: DesignSystemTheme.dark(),
      overrides: [createDetailEntryOverride(detailTestTask)],
    );
  }

  testWidgets('renders Timer label', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Timer'), findsOneWidget);
  });

  testWidgets('renders all action button icons', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
  });
}
