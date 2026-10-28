import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_filter_due_marker.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BoxDecoration?> markerDecoration(
    WidgetTester tester,
    DueDateUrgency? urgency,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(child: SavedFilterDueMarker(urgency: urgency)),
        ),
      ),
    );
    final boxes = find.descendant(
      of: find.byType(SavedFilterDueMarker),
      matching: find.byType(DecoratedBox),
    );
    if (boxes.evaluate().isEmpty) return null;
    return tester.widget<DecoratedBox>(boxes).decoration as BoxDecoration;
  }

  testWidgets('overdue is a 12px error-red disc', (tester) async {
    final decoration = await markerDecoration(tester, DueDateUrgency.overdue);
    final tokens = tester.element(find.byType(Scaffold)).designTokens;

    expect(decoration!.shape, BoxShape.circle);
    expect(decoration.color, tokens.colors.alert.error.defaultColor);
    expect(
      tester.getSize(find.byType(SavedFilterDueMarker)),
      Size.square(tokens.spacing.step4),
    );
  });

  testWidgets('due today is a warning-orange disc', (tester) async {
    final decoration = await markerDecoration(tester, DueDateUrgency.dueToday);
    final tokens = tester.element(find.byType(Scaffold)).designTokens;

    expect(decoration!.color, tokens.colors.alert.warning.defaultColor);
  });

  for (final urgency in [DueDateUrgency.normal, null]) {
    testWidgets('$urgency draws nothing and takes no space', (tester) async {
      expect(await markerDecoration(tester, urgency), isNull);
      expect(tester.getSize(find.byType(SavedFilterDueMarker)), Size.zero);
    });
  }

  test('speaks the same fact the disc shows', () {
    final messages = AppLocalizationsEn();
    expect(
      savedFilterDueMarkerSemantics(messages, DueDateUrgency.overdue),
      'Has overdue tasks',
    );
    expect(
      savedFilterDueMarkerSemantics(messages, DueDateUrgency.dueToday),
      'Has tasks due today',
    );
    expect(
      savedFilterDueMarkerSemantics(messages, DueDateUrgency.normal),
      isNull,
    );
    expect(savedFilterDueMarkerSemantics(messages, null), isNull);
  });
}
