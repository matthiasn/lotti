import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_avatar_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemAvatarWidgetbookComponent', () {
    testWidgets('builds the avatar overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemAvatarWidgetbookComponent(),
        expectedName: 'Avatars',
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
