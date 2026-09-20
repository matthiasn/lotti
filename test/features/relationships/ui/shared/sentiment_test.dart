import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('sentimentColor', () {
    testWidgets('maps each sentiment to the design-plan color', (tester) async {
      late DsTokens tokens;
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: Builder(
            builder: (context) {
              tokens = context.designTokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        sentimentColor(tokens, CheckInSentiment.delightful),
        tokens.colors.interactive.enabled,
      );
      expect(
        sentimentColor(tokens, CheckInSentiment.good),
        tokens.colors.alert.success.defaultColor,
      );
      expect(
        sentimentColor(tokens, CheckInSentiment.strained),
        tokens.colors.alert.warning.defaultColor,
      );
      expect(
        sentimentColor(tokens, CheckInSentiment.difficult),
        tokens.colors.alert.error.defaultColor,
      );
    });

    testWidgets('neutral is foreground at 38% alpha', (tester) async {
      late DsTokens tokens;
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: Builder(
            builder: (context) {
              tokens = context.designTokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final neutral = sentimentColor(tokens, CheckInSentiment.neutral);
      expect(neutral, tokens.colors.text.highEmphasis.withValues(alpha: 0.38));
    });
  });
}
