import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';

import '../../../widget_test_utils.dart';
import 'evolution_catalog_test_helpers.dart';

void main() {
  group('FeedbackClassification', () {
    testWidgets('renders analytics icon and sentiment chips', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 3,
            'negativeCount': 2,
            'neutralCount': 1,
          }),
        ),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('renders up to 5 feedback lines', (tester) async {
      final items = List.generate(
        5,
        (i) => <String, Object?>{
          'sentiment': 'positive',
          'category': 'general',
          'source': 'session',
          'detail': 'Feedback detail $i',
        },
      );

      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackClassificationItem, {
            'items': items,
            'positiveCount': 5,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(find.text('Feedback detail $i'), findsOneWidget);
      }
    });

    testWidgets(
      'colors the sentiment bar per item: red negative, green positive, '
      'orange neutral/default',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            buildCatalogWidget(feedbackClassificationItem, {
              'items': <Map<String, Object?>>[
                {'sentiment': 'negative', 'detail': 'Bad thing'},
                {'sentiment': 'positive', 'detail': 'Good thing'},
                {'sentiment': 'whatever', 'detail': 'Other thing'},
              ],
              'positiveCount': 1,
              'negativeCount': 1,
              'neutralCount': 1,
            }),
          ),
        );

        // Each feedback line renders a 4px-wide bar tinted by sentiment.
        Color barColorBeside(String detail) {
          final row = find.ancestor(
            of: find.text(detail),
            matching: find.byType(Row),
          );
          final bar = tester.widget<Container>(
            find
                .descendant(of: row.first, matching: find.byType(Container))
                .first,
          );
          return (bar.decoration! as BoxDecoration).color!;
        }

        expect(barColorBeside('Bad thing'), AgentPalette.red);
        expect(barColorBeside('Good thing'), AgentPalette.green);
        // Unknown sentiment falls into the default (neutral) branch.
        expect(barColorBeside('Other thing'), AgentPalette.orange);
      },
    );

    testWidgets('shows more text when items exceed 5', (tester) async {
      final items = List.generate(
        8,
        (i) => <String, Object?>{
          'sentiment': 'negative',
          'category': 'accuracy',
          'source': 'session',
          'detail': 'Detail $i',
        },
      );

      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackClassificationItem, {
            'items': items,
            'positiveCount': 0,
            'negativeCount': 8,
            'neutralCount': 0,
          }),
        ),
      );

      // First 5 details shown, remainder indicated by "more" text.
      expect(find.text('Detail 0'), findsOneWidget);
      expect(find.text('Detail 4'), findsOneWidget);
      // The "3 items" text reflects items.length - 5 = 3.
      expect(find.text('3 items'), findsOneWidget);
      // Detail 5 onwards should not be visible.
      expect(find.text('Detail 5'), findsNothing);
    });

    testWidgets('hides sentiment chips with zero count', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 0,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      expect(find.text('Positive Signals'), findsNothing);
      expect(find.text('Negative Signals'), findsNothing);
      expect(find.text('Neutral Signals'), findsNothing);
    });

    testWidgets('renders with empty items list', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 1,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });
  });

  group('FeedbackCategoryBreakdown', () {
    testWidgets('renders category icon and title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {
                'name': 'accuracy',
                'count': 5,
                'positiveCount': 3,
                'negativeCount': 2,
              },
            ],
          }),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('accuracy'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders proportion bars for multiple categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {'name': 'accuracy', 'count': 4, 'positiveCount': 2},
              {'name': 'communication', 'count': 6, 'negativeCount': 1},
            ],
          }),
        ),
      );

      expect(find.text('accuracy'), findsOneWidget);
      expect(find.text('communication'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('renders with empty categories list', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });

    testWidgets(
      'renders categories without optional positive/negative counts',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            buildCatalogWidget(feedbackCategoryBreakdownItem, {
              'categories': <Map<String, Object?>>[
                {'name': 'tooling', 'count': 3},
              ],
            }),
          ),
        );

        expect(find.text('tooling'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('proportion bar width factor equals count / totalCount', (
      tester,
    ) async {
      // totalCount = 4 + 6 = 10, so the per-category fractions are 0.4 and 0.6.
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {'name': 'accuracy', 'count': 4, 'positiveCount': 2},
              {'name': 'communication', 'count': 6, 'negativeCount': 1},
            ],
          }),
        ),
      );

      final widthFactors = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((w) => w.widthFactor!)
          .toList();

      expect(widthFactors, hasLength(2));
      // fraction = count / totalCount, and every fraction stays within [0, 1].
      expect(widthFactors[0], closeTo(0.4, 1e-9));
      expect(widthFactors[1], closeTo(0.6, 1e-9));
      for (final f in widthFactors) {
        expect(f, inInclusiveRange(0.0, 1.0));
      }
    });

    testWidgets(
      'neutral segment is clamped to zero when positive+negative exceed count',
      (tester) async {
        // count = 5 but positive + negative = 8, so neutralCount must clamp to
        // 0 (no orange Expanded) rather than going negative and throwing.
        await tester.pumpWidget(
          makeTestableWidget(
            buildCatalogWidget(feedbackCategoryBreakdownItem, {
              'categories': <Map<String, Object?>>[
                {
                  'name': 'overcounted',
                  'count': 5,
                  'positiveCount': 5,
                  'negativeCount': 3,
                },
              ],
            }),
          ),
        );

        // The colored segments live inside the FractionallySizedBox; the
        // header's name Expanded is excluded by scoping the search there.
        final flexes = tester
            .widgetList<Expanded>(
              find.descendant(
                of: find.byType(FractionallySizedBox),
                matching: find.byType(Expanded),
              ),
            )
            .map((w) => w.flex)
            .toList();
        // Only the negative (3) and positive (5) segments render; the clamped
        // neutral segment (0) is omitted, so exactly two segments exist and
        // every flex stays positive (never negative).
        expect(flexes, hasLength(2));
        expect(flexes, containsAll(<int>[3, 5]));
        for (final flex in flexes) {
          expect(flex, greaterThan(0));
        }
      },
    );
  });

  group('SessionProgress', () {
    testWidgets('renders loop icon, title, and session info', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 3,
            'totalSessions': 10,
            'feedbackCount': 7,
            'status': 'active',
          }),
        ),
      );

      expect(find.byIcon(Icons.loop), findsOneWidget);
      expect(find.text('Session 3 of 10'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders positive and negative metric chips when non-zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 1,
            'totalSessions': 5,
            'feedbackCount': 4,
            'positiveCount': 3,
            'negativeCount': 1,
            'status': 'completed',
          }),
        ),
      );

      expect(find.text('3'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('hides positive and negative chips when zero', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 2,
            'totalSessions': 8,
            'feedbackCount': 0,
            'positiveCount': 0,
            'negativeCount': 0,
            'status': 'active',
          }),
        ),
      );

      expect(find.text('+'), findsNothing);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('renders completed status', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 5,
            'totalSessions': 5,
            'feedbackCount': 10,
            'status': 'completed',
          }),
        ),
      );

      expect(find.text('Session 5 of 5'), findsOneWidget);
    });

    testWidgets('renders abandoned status', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 2,
            'totalSessions': 5,
            'feedbackCount': 3,
            'status': 'abandoned',
          }),
        ),
      );

      expect(find.text('Session 2 of 5'), findsOneWidget);
    });
  });
}
