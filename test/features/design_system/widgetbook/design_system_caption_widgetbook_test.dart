import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/captions/design_system_caption.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_caption_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemCaptionWidgetbookComponent', () {
    testWidgets('builds the caption overview use case', (tester) async {
      final component = buildDesignSystemCaptionWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Caption');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Caption Variants'), findsOneWidget);
      // 3 icon positions × 2 action options = 6 captions
      expect(find.byType(DesignSystemCaption), findsNWidgets(6));
    });
  });
}
