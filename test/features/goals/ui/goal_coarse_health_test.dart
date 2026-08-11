import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

void main() {
  late AppLocalizations en;
  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('coarseHealthOf collapses every runtime status', () {
    test('keeping up or better reads healthy', () {
      expect(coarseHealthOf(GoalTrackStatus.onTrack), GoalCoarseHealth.healthy);
      expect(
        coarseHealthOf(GoalTrackStatus.achieved),
        GoalCoarseHealth.healthy,
      );
    });

    test('at risk and off track both read behind', () {
      expect(coarseHealthOf(GoalTrackStatus.atRisk), GoalCoarseHealth.behind);
      expect(
        coarseHealthOf(GoalTrackStatus.offTrack),
        GoalCoarseHealth.behind,
      );
    });

    test('recovering reads restarting — a beginning, never a failure', () {
      expect(
        coarseHealthOf(GoalTrackStatus.recovering),
        GoalCoarseHealth.restarting,
      );
    });

    test(
      'insufficient data and a missing register both read notEnoughData',
      () {
        expect(
          coarseHealthOf(GoalTrackStatus.insufficientData),
          GoalCoarseHealth.notEnoughData,
        );
        expect(coarseHealthOf(null), GoalCoarseHealth.notEnoughData);
      },
    );

    test('the full mapping is exhaustive and intentional — a new status '
        'cannot slip through without an explicit bucket', () {
      const expected = {
        GoalTrackStatus.onTrack: GoalCoarseHealth.healthy,
        GoalTrackStatus.achieved: GoalCoarseHealth.healthy,
        GoalTrackStatus.atRisk: GoalCoarseHealth.behind,
        GoalTrackStatus.offTrack: GoalCoarseHealth.behind,
        GoalTrackStatus.recovering: GoalCoarseHealth.restarting,
        GoalTrackStatus.insufficientData: GoalCoarseHealth.notEnoughData,
      };
      // Guards against a new GoalTrackStatus being added without deciding its
      // coarse bucket here.
      expect(expected.keys.toSet(), GoalTrackStatus.values.toSet());
      for (final MapEntry(key: status, value: bucket) in expected.entries) {
        expect(coarseHealthOf(status), bucket, reason: '$status');
      }
    });
  });

  group('goalCoarseHealthColor binds the intended token in both themes', () {
    for (final (name, tokens) in [
      ('light', dsTokensLight),
      ('dark', dsTokensDark),
    ]) {
      test('$name theme', () {
        final colors = tokens.colors;
        expect(
          goalCoarseHealthColor(GoalCoarseHealth.healthy, colors),
          colors.alert.success.defaultColor,
        );
        expect(
          goalCoarseHealthColor(GoalCoarseHealth.behind, colors),
          colors.alert.warning.defaultColor,
        );
        // Restarting is the interactive teal — deliberately not red.
        expect(
          goalCoarseHealthColor(GoalCoarseHealth.restarting, colors),
          colors.interactive.enabled,
        );
        expect(
          goalCoarseHealthColor(GoalCoarseHealth.notEnoughData, colors),
          colors.text.lowEmphasis,
        );
      });
    }
  });

  group('direction helpers cover every arrow', () {
    test('icon per direction', () {
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.up),
        Icons.trending_up_rounded,
      );
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.flat),
        Icons.trending_flat_rounded,
      );
      expect(
        goalHealthDirectionIcon(GoalHealthDirection.down),
        Icons.trending_down_rounded,
      );
    });

    test('screen-reader label per direction, distinct and non-empty', () {
      final labels = {
        for (final d in GoalHealthDirection.values)
          d: goalHealthDirectionLabel(en, d),
      };
      expect(labels.values.toSet(), hasLength(3), reason: 'all distinct');
      expect(labels.values.every((l) => l.isNotEmpty), isTrue);
      expect(labels[GoalHealthDirection.up], en.goalHealthTrendUp);
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

    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.text(en.goalHealthTrendUp), findsOneWidget);
  });

  group('GoalCoarseHealthChip', () {
    // The contrast fix: the label reads in high-emphasis text (which the
    // design system tunes for legibility in each theme) rather than the raw
    // health hue over a 22% wash of that same hue — a full-hue caption fails
    // the 4.5:1 floor for success/warning/restarting in the light theme. The
    // hue stays in the fill. Verified in BOTH theme bindings and for every
    // coarse state, so a regression to a hue-coloured caption fails here.
    for (final (themeName, base) in [
      ('light', null),
      ('dark', ThemeData.dark()),
    ]) {
      testWidgets('$themeName: label uses high-emphasis text (never the raw '
          'hue), fill carries the hue wash', (tester) async {
        for (final health in GoalCoarseHealth.values) {
          await tester.pumpWidget(
            makeTestableWidget(
              Theme(
                data: resolveTestTheme(base),
                child: GoalCoarseHealthChip(health: health),
              ),
            ),
          );
          await tester.pump();

          final colors = resolveTestTheme(base).extension<DsTokens>()!.colors;
          final hue = goalCoarseHealthColor(health, colors);

          final text = tester.widget<Text>(find.byType(Text));
          expect(
            text.style?.color,
            colors.text.highEmphasis,
            reason: '$health: the hue lives in the fill, not the caption text',
          );
          expect(
            text.style?.color,
            isNot(hue),
            reason: '$health: a raw-hue caption is the contrast failure',
          );

          final container = tester.widget<Container>(
            find
                .ancestor(
                  of: find.byType(Text),
                  matching: find.byType(Container),
                )
                .first,
          );
          final fill = (container.decoration! as BoxDecoration).color!;
          expect(fill.r, hue.r);
          expect(fill.g, hue.g);
          expect(fill.b, hue.b);
          expect(fill.a, lessThan(1), reason: 'the fill is a wash, not solid');
        }
      });
    }
  });
}
