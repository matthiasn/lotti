import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_cancel_stop_buttons.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_circle_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../test_utils/material_ui_finders.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    VoidCallback? onCancel,
    VoidCallback? onStop,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionCancelStopButtons(
        onCancel: onCancel ?? () {},
        onStop: onStop ?? () {},
        cancelTooltip: 'Cancel recording',
        stopTooltip: 'Stop recording',
      ),
    );
  }

  testWidgets('renders cancel and stop circle buttons with tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(EvolutionCircleButton), findsNWidgets(2));
    expect(find.byIcon(LottiIcons.close), findsOneWidget);
    expect(find.byIcon(LottiIcons.stop), findsOneWidget);
    expect(findMaterialTooltip('Cancel recording'), findsOneWidget);
    expect(findMaterialTooltip('Stop recording'), findsOneWidget);
  });

  testWidgets('tapping the close button invokes only onCancel', (
    tester,
  ) async {
    var cancels = 0;
    var stops = 0;
    await tester.pumpWidget(
      buildSubject(onCancel: () => cancels++, onStop: () => stops++),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LottiIcons.close));
    expect(cancels, 1);
    expect(stops, 0);
  });

  testWidgets('tapping the stop button invokes only onStop', (tester) async {
    var cancels = 0;
    var stops = 0;
    await tester.pumpWidget(
      buildSubject(onCancel: () => cancels++, onStop: () => stops++),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LottiIcons.stop));
    expect(stops, 1);
    expect(cancels, 0);
  });
}
