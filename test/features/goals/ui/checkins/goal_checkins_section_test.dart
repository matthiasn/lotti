import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkins_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final today = DateTime(2026, 8, 18, 9);

  GoalAudioCheckIn checkIn(String id, {int minutesAgo = 0}) {
    final at = today.subtract(Duration(minutes: minutesAgo));
    return GoalAudioCheckIn(
      JournalAudio(
        meta: Metadata(
          id: id,
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
        ),
        data: AudioData(
          dateFrom: at,
          dateTo: at.add(const Duration(seconds: 12)),
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 12),
        ),
        entryText: EntryText(plainText: 'note $id'),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<GoalTimelineItem> items,
    VoidCallback? onSeeAll,
    int? maxBeats,
  }) => withClock(
    Clock.fixed(today.add(const Duration(hours: 1))),
    () => tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalCheckInsSection(
          agentId: 'agent-1',
          onSeeAll: onSeeAll,
          maxBeats: maxBeats,
        ),
        overrides: [
          goalTimelineItemsProvider('agent-1').overrideWithValue(items),
          goalCheckInsLoadProvider(
            'agent-1',
          ).overrideWithValue(GoalCheckInsLoad.settled),
        ],
      ),
    ),
  );

  testWidgets('the header counts what the user has said', (tester) async {
    await pump(
      tester,
      items: [checkIn('a'), checkIn('b', minutesAgo: 5)],
    );

    expect(find.text('Check-ins · 2'), findsOneWidget);
  });

  testWidgets('an empty goal shows the title alone and the invitation — and '
      "no button: speaking is the page bar's", (tester) async {
    await pump(tester, items: const []);

    // "Check-ins · 0" would be a scoreboard of nothing.
    expect(find.text('Check-ins'), findsOneWidget);
    expect(
      find.textContaining('Tell your agent what is actually going on'),
      findsOneWidget,
    );
    // Three doors to one sheet — a header plus, an empty-state button and
    // the app-bar mic — are now the one Speak bar.
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.byIcon(LottiIcons.mic), findsNothing);
    expect(find.byIcon(LottiIcons.addCircled), findsNothing);
  });

  testWidgets("a section, not a card: the heading shares the rows' left "
      'edge and wears the page-section tier', (tester) async {
    await pump(tester, items: [checkIn('a')]);

    final heading = find.byKey(const ValueKey('goal-checkins-heading'));
    final tokens = tester.element(heading).designTokens;
    expect(
      tester.widget<Text>(heading).style?.fontSize,
      tokens.typography.styles.subtitle.subtitle1.fontSize,
    );
    expect(find.byType(DesignSystemSectionCard), findsNothing);
    expect(
      tester.getTopLeft(heading).dx,
      tester.getTopLeft(find.byType(DesignSystemTimelineSectionHeader)).dx +
          tokens.spacing.step3,
    );
  });

  testWidgets('See all appears only when the preview hides something', (
    tester,
  ) async {
    var seen = 0;
    await pump(
      tester,
      items: [checkIn('a'), checkIn('b', minutesAgo: 5)],
      maxBeats: 3,
      onSeeAll: () => seen++,
    );
    expect(find.byKey(const ValueKey('goal-checkin-see-all')), findsNothing);

    await pump(
      tester,
      items: [
        for (var i = 0; i < 5; i++) checkIn('c$i', minutesAgo: i),
      ],
      maxBeats: 3,
      onSeeAll: () => seen++,
    );
    await tester.tap(find.byKey(const ValueKey('goal-checkin-see-all')));
    expect(seen, 1);
  });

  testWidgets('the desktop rail shows everything and offers no See all', (
    tester,
  ) async {
    await pump(
      tester,
      items: [checkIn('a'), checkIn('b', minutesAgo: 5)],
      onSeeAll: () {},
    );

    // maxBeats null means the rail is already showing the loaded history.
    expect(find.byKey(const ValueKey('goal-checkin-see-all')), findsNothing);
  });

  testWidgets('See all is a quiet link: no hover fill, its own ink lifts', (
    tester,
  ) async {
    await pump(
      tester,
      items: [
        for (var i = 0; i < 5; i++) checkIn('c$i', minutesAgo: i),
      ],
      maxBeats: 3,
      onSeeAll: () {},
    );

    final row = find.byKey(const ValueKey('goal-checkin-see-all'));
    final ink = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)),
    );
    expect(ink.hoverColor, Colors.transparent);
    expect(
      ink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );

    final tokens = tester.element(row).designTokens;
    Text label() => tester.widget<Text>(find.text('See all check-ins'));
    expect(label().style?.color, tokens.colors.interactive.enabled);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(row));
    await tester.pump();
    expect(label().style?.color, tokens.colors.interactive.hover);
    await gesture.moveTo(Offset.zero);
    await tester.pump();
  });
}
