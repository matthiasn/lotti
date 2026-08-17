import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';

void main() {
  test('goal nudges keep exactly their pre-generalization surfaces — '
      'tasks, dailyOs, habits — and stay off the People pages', () {
    expect(
      nudgeKindShowsOn(NudgeBannerKind.goal, NudgeBannerSurface.tasks),
      isTrue,
    );
    expect(
      nudgeKindShowsOn(NudgeBannerKind.goal, NudgeBannerSurface.dailyOs),
      isTrue,
    );
    expect(
      nudgeKindShowsOn(NudgeBannerKind.goal, NudgeBannerSurface.habits),
      isTrue,
    );
    expect(
      nudgeKindShowsOn(NudgeBannerKind.goal, NudgeBannerSurface.people),
      isFalse,
      reason:
          'a goal ad on the People tab would be a behavior change '
          'for goals AND noise for relationships (ADR 0059 Decision 6)',
    );
  });

  test('relationship nudges speak on every dock surface including People', () {
    for (final surface in NudgeBannerSurface.values) {
      expect(
        nudgeKindShowsOn(NudgeBannerKind.relationship, surface),
        isTrue,
        reason: '$surface',
      );
    }
  });
}
