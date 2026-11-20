import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_list_items/design_system_priority_glyph.dart';
import 'package:lotti/features/design_system/components/task_list_items/design_system_task_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<SvgPicture> pumpGlyph(
    WidgetTester tester,
    DesignSystemTaskPriority priority,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(DesignSystemPriorityGlyph(priority: priority)),
    );
    return tester.widget<SvgPicture>(find.byType(SvgPicture));
  }

  testWidgets('each level draws its own mark, so no two priorities match', (
    tester,
  ) async {
    const expected = {
      DesignSystemTaskPriority.p0: 'assets/design_system/task_priority_p0.svg',
      DesignSystemTaskPriority.p1:
          'assets/design_system/task_priority_high.svg',
      DesignSystemTaskPriority.p2:
          'assets/design_system/task_priority_medium.svg',
      DesignSystemTaskPriority.p3: 'assets/design_system/task_priority_low.svg',
    };
    for (final entry in expected.entries) {
      final svg = await pumpGlyph(tester, entry.key);
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        entry.value,
        reason: '${entry.key}',
      );
      expect(svg.width, IconSizes.s);
    }
  });

  testWidgets('only urgency earns colour: medium sits at high-emphasis ink', (
    tester,
  ) async {
    Future<void> expectTint(
      DesignSystemTaskPriority priority,
      Color Function(DsTokens tokens) color,
    ) async {
      final svg = await pumpGlyph(tester, priority);
      final tokens = tester.element(find.byType(SvgPicture)).designTokens;
      expect(
        svg.colorFilter,
        ColorFilter.mode(color(tokens), BlendMode.srcIn),
        reason: '$priority',
      );
    }

    await expectTint(
      DesignSystemTaskPriority.p0,
      (t) => t.colors.alert.error.defaultColor,
    );
    await expectTint(
      DesignSystemTaskPriority.p1,
      (t) => t.colors.alert.warning.defaultColor,
    );
    await expectTint(
      DesignSystemTaskPriority.p2,
      (t) => t.colors.text.highEmphasis,
    );
    await expectTint(
      DesignSystemTaskPriority.p3,
      (t) => t.colors.text.mediumEmphasis,
    );
  });
}
