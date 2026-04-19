import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BuildContext> pumpCard(
    WidgetTester tester, {
    VoidCallback? onTap,
    Widget child = const Text('body'),
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) {
            captured = context;
            return TaskDetailSectionCard(
              onTap: onTap,
              child: child,
            );
          },
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  testWidgets('renders child with level02 surface and radii.l corners', (
    tester,
  ) async {
    final context = await pumpCard(tester);
    expect(find.text('body'), findsOneWidget);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(
      decoration.color,
      TaskShowcasePalette.surface(context),
    );
    expect(
      decoration.borderRadius,
      BorderRadius.circular(context.designTokens.radii.l),
    );
    expect(decoration.gradient, isNull);
    // The flat card deliberately draws no shadow — matches the task list.
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('without onTap, no InkWell is rendered', (tester) async {
    await pumpCard(tester);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('onTap fires and renders an InkWell', (tester) async {
    var tapped = 0;
    await pumpCard(tester, onTap: () => tapped++);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('body'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
