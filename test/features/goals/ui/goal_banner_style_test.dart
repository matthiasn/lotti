import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';

import '../../../widget_test_utils.dart';

void main() {
  test('every accent preset resolves to existing design-system tokens — '
      'no banner introduces a colour of its own', () {
    final tokens = resolveTestTheme().extension<DsTokens>()!;
    final colors = tokens.colors;

    final calm = goalBannerAccentStyle(GoalBannerAccent.calm, colors);
    expect(calm.accent, colors.aiCard.accent);
    expect(calm.fill, colors.aiCard.accentSoft);

    final tide = goalBannerAccentStyle(GoalBannerAccent.tide, colors);
    expect(tide.accent, colors.alert.info.defaultColor);

    final ember = goalBannerAccentStyle(GoalBannerAccent.ember, colors);
    expect(ember.accent, colors.alert.warning.defaultColor);

    final neon = goalBannerAccentStyle(GoalBannerAccent.neon, colors);
    expect(neon.accent, colors.interactive.enabled);

    final aurora = goalBannerAccentStyle(GoalBannerAccent.aurora, colors);
    expect(aurora.accent, colors.decorative.level03);

    // Non-aiCard fills are the accent hue receding at the card-fill
    // alpha, never a new colour.
    for (final style in [tide, ember, neon]) {
      expect(
        style.fill.toARGB32() & 0x00FFFFFF,
        style.accent.toARGB32() & 0x00FFFFFF,
      );
    }
  });
}
