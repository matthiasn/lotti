import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('direction helpers cover every arrow', () {
    test('icon per direction', () {
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.up),
        LottiIcons.trendingUp,
      );
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.flat),
        LottiIcons.forward,
      );
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.down),
        LottiIcons.trendingDown,
      );
    });

    test('screen-reader label per direction is distinct and localized', () {
      final labels = {
        for (final direction in GoalHealthDirection.values)
          direction: goalHealthDirectionLabel(en, direction),
      };
      expect(labels.values.toSet(), hasLength(3));
      expect(labels[GoalHealthDirection.up], en.goalHealthTrendUp);
      expect(labels[GoalHealthDirection.flat], en.goalHealthTrendFlat);
      expect(labels[GoalHealthDirection.down], en.goalHealthTrendDown);
    });

    for (final (name, tokens) in [
      ('light', dsTokensLight),
      ('dark', dsTokensDark),
    ]) {
      test('$name theme uses an independent semantic hue', () {
        expect(
          goalHealthDirectionColor(GoalHealthDirection.up, tokens.colors),
          tokens.colors.alert.success.defaultColor,
        );
        expect(
          goalHealthDirectionColor(GoalHealthDirection.flat, tokens.colors),
          tokens.colors.text.lowEmphasis,
        );
        expect(
          goalHealthDirectionColor(GoalHealthDirection.down, tokens.colors),
          tokens.colors.alert.warning.defaultColor,
        );
      });
    }
  });

  testWidgets('direction chip renders its icon and localized label', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalHealthDirectionChip(direction: GoalHealthDirection.up),
      ),
    );

    expect(find.byIcon(LottiIcons.trendingUp), findsOneWidget);
    expect(find.text(en.goalHealthTrendUp), findsOneWidget);
  });
}
