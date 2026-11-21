import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/ai_summary_load_error.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('one quiet line with a dense retry that calls back', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        AiSummaryLoadError(onRetry: () => retries++),
      ),
    );

    expect(find.text("Couldn't load this task's agent"), findsOneWidget);
    final retry = tester.widget<DesignSystemButton>(
      find.byType(DesignSystemButton),
    );
    // Caption-tier: the retry never out-weighs the line it sits on.
    expect(retry.size, DesignSystemButtonSize.dense);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
