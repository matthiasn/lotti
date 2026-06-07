import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/learning_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

LearningCard _standard({
  String id = 'card_std',
  String overline = 'YESTERDAY',
  String summary = 'You finished focus work.',
  List<LearningBullet> bullets = const [
    LearningBullet(
      text: 'Carried over: design polish',
      tone: LearningBulletTone.info,
    ),
    LearningBullet(
      text: 'Energy: strong morning',
      tone: LearningBulletTone.positive,
    ),
    LearningBullet(
      text: 'Beware mid-day context switching',
      tone: LearningBulletTone.warning,
    ),
  ],
}) => LearningCard(
  id: id,
  overline: overline,
  summary: summary,
  bullets: bullets,
);

LearningCard _nudge({
  String id = 'card_nudge',
  String overline = 'GENTLE NUDGE',
  String summary = 'Protect mornings for deep work.',
}) => LearningCard(
  id: id,
  overline: overline,
  summary: summary,
  bullets: const [],
  kind: LearningCardKind.nudge,
);

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(800, 1200)),
);

void main() {
  group('LearningCardsColumn', () {
    testWidgets('renders one card per entry with overline + summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LearningCardsColumn(
            cards: [
              _standard(),
              _standard(
                id: 'b',
                overline: 'THIS WEEK',
                summary: 'You shipped 3 things.',
              ),
            ],
          ),
        ),
      );

      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('You finished focus work.'), findsOneWidget);
      expect(find.text('You shipped 3 things.'), findsOneWidget);
    });

    testWidgets('renders each bullet line with its tone-specific icon', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(LearningCardsColumn(cards: [_standard()])));

      expect(find.text('Carried over: design polish'), findsOneWidget);
      expect(find.text('Energy: strong morning'), findsOneWidget);
      expect(find.text('Beware mid-day context switching'), findsOneWidget);
      // Tone-specific icons: info → arrow, positive → sparkle, warning → shuffle.
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    });

    testWidgets('nudge card variant shows Accept + Decline pill buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(LearningCardsColumn(cards: [_nudge()])));

      final messages = tester
          .element(find.byType(LearningCardsColumn))
          .messages;
      expect(find.text('GENTLE NUDGE'), findsOneWidget);
      expect(find.text('Protect mornings for deep work.'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextDraftingNudgeAccept),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextDraftingNudgeDecline),
        findsOneWidget,
      );
      // The nudge variant has no standard bullet icons.
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('mixed list keeps standard + nudge variants distinct', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LearningCardsColumn(cards: [_standard(), _nudge()]),
        ),
      );

      final messages = tester
          .element(find.byType(LearningCardsColumn))
          .messages;
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('GENTLE NUDGE'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextDraftingNudgeAccept),
        findsOneWidget,
      );
      // Standard bullets still render with their icons.
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('empty list renders no card content', (tester) async {
      await tester.pumpWidget(_wrap(const LearningCardsColumn(cards: [])));

      // Semantic emptiness: the column itself renders no text or icons —
      // host scaffolding (which may legitimately use Container) is ignored.
      expect(
        find.descendant(
          of: find.byType(LearningCardsColumn),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(LearningCardsColumn),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('Accept / Decline buttons are tappable without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(LearningCardsColumn(cards: [_nudge()])));
      final messages = tester
          .element(find.byType(LearningCardsColumn))
          .messages;

      await tester.tap(find.text(messages.dailyOsNextDraftingNudgeAccept));
      await tester.pump();
      await tester.tap(find.text(messages.dailyOsNextDraftingNudgeDecline));
      await tester.pump();
      // Both still visible after tap — handlers are no-ops by design.
      expect(
        find.text(messages.dailyOsNextDraftingNudgeAccept),
        findsOneWidget,
      );
      expect(
        find.text(messages.dailyOsNextDraftingNudgeDecline),
        findsOneWidget,
      );
    });
  });
}
