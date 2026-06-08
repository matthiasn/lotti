import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/captions/design_system_caption.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_caption_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemCaptionWidgetbookComponent', () {
    testWidgets('builds the caption overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemCaptionWidgetbookComponent(),
        expectedName: 'Caption',
      );

      expect(find.text('Caption Variants'), findsOneWidget);
      // 3 icon positions × 2 action options = 6 captions
      expect(find.byType(DesignSystemCaption), findsNWidgets(6));

      // Interaction smoke: tapping the first DesignSystemCaption (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemCaption).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
