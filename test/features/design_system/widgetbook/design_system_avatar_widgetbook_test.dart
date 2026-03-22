import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_avatar_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemAvatarWidgetbookComponent', () {
    testWidgets('builds the avatar overview use case', (tester) async {
      final component = buildDesignSystemAvatarWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Avatars');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Status Matrix'), findsOneWidget);
      expect(find.text('Size Matrix'), findsOneWidget);
      expect(
        find.byType(DesignSystemAvatar),
        findsAtLeastNWidgets(
          DesignSystemAvatarStatus.values.length +
              DesignSystemAvatarSize.values.length,
        ),
      );
    });
  });
}
