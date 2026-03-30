import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/features/settings/widgetbook/settings_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildSettingsWidgetbookFolder', () {
    late WidgetbookUseCase useCase;

    setUp(() {
      final folder = buildSettingsWidgetbookFolder();
      final children = folder.children;
      expect(children, isNotNull);
      final component = children!.single as WidgetbookComponent;
      expect(component.name, 'Settings page');
      useCase = component.useCases.single;
    });

    testWidgets('renders settings list with all items', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Should render 9 settings items
      expect(find.byType(DesignSystemListItem), findsNWidgets(9));

      // Verify localized titles are rendered
      expect(find.text('AI Settings'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);

      // Verify subtitles are rendered
      expect(
        find.text('Configure AI providers, models, and prompts'),
        findsOneWidget,
      );

      // Chevrons should be present for each item
      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsNWidgets(9),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode with correct theme colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(find.byType(DesignSystemListItem), findsNWidgets(9));

      // Verify the background uses dark theme color
      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final boxDecoration = decoratedBox.decoration as BoxDecoration;
      final darkBg = dsTokensDark.colors.background.level01;
      expect(boxDecoration.color, equals(darkBg));

      expect(tester.takeException(), isNull);
    });
  });
}
