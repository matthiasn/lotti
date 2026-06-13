import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import 'evolution_catalog_test_helpers.dart';

void main() {
  group('CategoryRatings', () {
    testWidgets('returns shrink widget when categories are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(categoryRatingsItem, {
            'categories': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.text('Approve & Save'), findsNothing);
    });

    testWidgets(
      'submits selected category ratings as ratings_submitted event',
      (tester) async {
        final events = <UiEvent>[];

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final itemContext = CatalogItemContext(
                  data: <String, Object?>{
                    'categories': <Map<String, Object?>>[
                      {'name': 'accuracy', 'label': 'Accuracy'},
                      {'name': 'communication', 'label': 'Communication'},
                    ],
                  },
                  id: 'ratings-component',
                  type: 'CategoryRatings',
                  buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                  dispatchEvent: events.add,
                  buildContext: context,
                  dataContext: DataContext(InMemoryDataModel(), DataPath.root),
                  getComponent: (_) => null,
                  getCatalogItem: (_) => null,
                  surfaceId: 'ratings-surface',
                  reportError: (_, _) {},
                );
                return categoryRatingsItem.widgetBuilder(itemContext);
              },
            ),
          ),
        );

        final messagesContext = tester.element(find.text('Accuracy'));

        expect(find.text('Accuracy'), findsOneWidget);
        expect(find.text('Communication'), findsOneWidget);
        expect(
          find.text(messagesContext.messages.agentCategoryRatingsTitle),
          findsOneWidget,
        );
        expect(
          find.text(messagesContext.messages.agentCategoryRatingsSubtitle),
          findsOneWidget,
        );
        expect(
          find.text(messagesContext.messages.agentCategoryRatingsScaleMin),
          findsNWidgets(2),
        );
        expect(
          find.text(messagesContext.messages.agentCategoryRatingsScaleMax),
          findsNWidgets(2),
        );

        final firstRow = find
            .ancestor(
              of: find.text('Accuracy'),
              matching: find.byType(Padding),
            )
            .first;
        final secondRow = find
            .ancestor(
              of: find.text('Communication'),
              matching: find.byType(Padding),
            )
            .first;

        await tester.tap(
          find
              .descendant(of: firstRow, matching: find.byType(GestureDetector))
              .at(3),
        );
        await tester.pump();
        await tester.tap(
          find
              .descendant(of: secondRow, matching: find.byType(GestureDetector))
              .at(1),
        );
        await tester.pump();

        final localizedContext = tester.element(find.text('Accuracy'));
        await tester.tap(
          find.text(localizedContext.messages.agentCategoryRatingsSubmit),
        );
        // Submit only flips `_submitted` via setState — no animation to settle.
        await tester.pump();

        expect(events, hasLength(1));
        final event = events.first as UserActionEvent;
        expect(event.name, 'ratings_submitted');
        expect(event.surfaceId, 'ratings-surface');

        final ratings =
            jsonDecode(event.sourceComponentId) as Map<String, dynamic>;
        expect(ratings, {'accuracy': 4, 'communication': 2});

        // After submit, the button is replaced by a confirmation row.
        expect(
          find.text(localizedContext.messages.agentCategoryRatingsSubmit),
          findsOneWidget,
        );
        expect(
          find.byIcon(Icons.check_circle_rounded),
          findsOneWidget,
        );
      },
    );

    testWidgets('disambiguates duplicate and empty category names on submit', (
      tester,
    ) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: <String, Object?>{
                  'categories': <Map<String, Object?>>[
                    {'name': 'accuracy', 'label': 'Accuracy A'},
                    {'name': 'accuracy', 'label': 'Accuracy B'},
                    {'name': '', 'label': 'Unlabeled'},
                  ],
                },
                id: 'ratings-component',
                type: 'CategoryRatings',
                buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                dispatchEvent: events.add,
                buildContext: context,
                dataContext: DataContext(InMemoryDataModel(), DataPath.root),
                getComponent: (_) => null,
                getCatalogItem: (_) => null,
                surfaceId: 'ratings-surface',
                reportError: (_, _) {},
              );
              return categoryRatingsItem.widgetBuilder(itemContext);
            },
          ),
        ),
      );

      final firstRow = find
          .ancestor(
            of: find.text('Accuracy A'),
            matching: find.byType(Padding),
          )
          .first;
      final secondRow = find
          .ancestor(
            of: find.text('Accuracy B'),
            matching: find.byType(Padding),
          )
          .first;
      final thirdRow = find
          .ancestor(
            of: find.text('Unlabeled'),
            matching: find.byType(Padding),
          )
          .first;

      await tester.tap(
        find
            .descendant(of: firstRow, matching: find.byType(GestureDetector))
            .first,
      );
      await tester.pump();
      await tester.tap(
        find
            .descendant(of: secondRow, matching: find.byType(GestureDetector))
            .at(4),
      );
      await tester.pump();
      await tester.tap(
        find
            .descendant(of: thirdRow, matching: find.byType(GestureDetector))
            .at(2),
      );
      await tester.pump();

      final localizedContext = tester.element(find.text('Accuracy A'));
      await tester.tap(
        find.text(localizedContext.messages.agentCategoryRatingsSubmit),
      );
      // Submit only flips `_submitted` via setState — no animation to settle.
      await tester.pump();

      final event = events.single as UserActionEvent;
      final ratings =
          jsonDecode(event.sourceComponentId) as Map<String, dynamic>;
      expect(ratings, {
        'accuracy': 1,
        'accuracy_1': 5,
        'category_2': 3,
      });
    });
  });

  group('BinaryChoicePrompt', () {
    testWidgets('renders question and optional detail', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(binaryChoicePromptItem, {
            'question': 'Want to rate me?',
            'detail': 'A quick yes or no is enough.',
          }),
        ),
      );

      expect(find.text('Want to rate me?'), findsOneWidget);
      expect(find.text('A quick yes or no is enough.'), findsOneWidget);
    });

    testWidgets('uses custom confirm and dismiss labels when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(binaryChoicePromptItem, {
            'question': 'Proceed?',
            'confirmLabel': 'Absolutely',
            'dismissLabel': 'Not now',
          }),
        ),
      );

      final context = tester.element(find.text('Proceed?'));

      // Custom labels are rendered instead of the default Yes/No.
      expect(find.text('Absolutely'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      // Default localized labels are absent.
      expect(find.text(context.messages.agentBinaryChoiceYes), findsNothing);
      expect(find.text(context.messages.agentBinaryChoiceNo), findsNothing);
    });

    testWidgets('dispatches binary_choice_submitted with semantic payload', (
      tester,
    ) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: const <String, Object?>{
                  'question': 'Want to rate me?',
                  'confirmValue': 'Yes, show the rating form.',
                  'dismissValue': 'No, skip ratings for now.',
                },
                id: 'binary-choice-component',
                type: 'BinaryChoicePrompt',
                buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                dispatchEvent: events.add,
                buildContext: context,
                dataContext: DataContext(InMemoryDataModel(), DataPath.root),
                getComponent: (_) => null,
                getCatalogItem: (_) => null,
                surfaceId: 'binary-choice-surface',
                reportError: (_, _) {},
              );
              return binaryChoicePromptItem.widgetBuilder(itemContext);
            },
          ),
        ),
      );

      await tester.tap(find.text('Yes'));
      // Choosing an option only flips `_submitted` via setState — no animation.
      await tester.pump();

      final event = events.single as UserActionEvent;
      expect(event.name, 'binary_choice_submitted');
      expect(event.surfaceId, 'binary-choice-surface');
      expect(
        jsonDecode(event.sourceComponentId),
        {'value': 'Yes, show the rating form.'},
      );
    });
  });

  group('HighPriorityFeedback', () {
    testWidgets('renders priority icon and title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[
              {'agentId': 'abc12345', 'detail': 'User asked P0 but got P1'},
            ],
            'excellenceNotes': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.byIcon(Icons.priority_high), findsOneWidget);
      final context = tester.element(find.byIcon(Icons.priority_high));
      expect(
        find.text(context.messages.agentFeedbackHighPriorityTitle),
        findsOneWidget,
      );
    });

    testWidgets('renders grievances with red accent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[
              {'agentId': 'abc12345', 'detail': 'Missed critical deadline'},
              {'agentId': 'def67890', 'detail': 'Wrong priority assignment'},
            ],
            'excellenceNotes': <Map<String, Object?>>[],
          }),
        ),
      );

      final context = tester.element(find.byIcon(Icons.priority_high));
      expect(
        find.textContaining(context.messages.agentFeedbackGrievancesTitle),
        findsOneWidget,
      );
      expect(find.text('Missed critical deadline'), findsOneWidget);
      expect(find.text('Wrong priority assignment'), findsOneWidget);
      expect(find.text('[abc12345]'), findsOneWidget);
      expect(find.text('[def67890]'), findsOneWidget);
    });

    testWidgets('renders excellence notes with green accent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[],
            'excellenceNotes': <Map<String, Object?>>[
              {'agentId': 'xyz99999', 'detail': 'Outstanding report quality'},
            ],
          }),
        ),
      );

      final context = tester.element(find.byIcon(Icons.priority_high));
      expect(
        find.textContaining(context.messages.agentFeedbackExcellenceTitle),
        findsOneWidget,
      );
      expect(find.text('Outstanding report quality'), findsOneWidget);
      expect(find.text('[xyz99999]'), findsOneWidget);
    });

    testWidgets('renders both grievances and excellence notes', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[
              {'agentId': 'aaa', 'detail': 'Grievance item'},
            ],
            'excellenceNotes': <Map<String, Object?>>[
              {'agentId': 'bbb', 'detail': 'Excellence item'},
            ],
          }),
        ),
      );

      expect(find.text('Grievance item'), findsOneWidget);
      expect(find.text('Excellence item'), findsOneWidget);
    });

    testWidgets('returns shrink widget when both lists are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[],
            'excellenceNotes': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.byIcon(Icons.priority_high), findsNothing);
    });

    testWidgets('renders item without agentId gracefully', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[
              {'agentId': '', 'detail': 'Anonymous grievance'},
            ],
            'excellenceNotes': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.text('Anonymous grievance'), findsOneWidget);
      // Should not render empty brackets.
      expect(find.text('[]'), findsNothing);
    });

    testWidgets('shows grievance count in section header', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(highPriorityFeedbackItem, {
            'grievances': <Map<String, Object?>>[
              {'agentId': 'a', 'detail': 'One'},
              {'agentId': 'b', 'detail': 'Two'},
              {'agentId': 'c', 'detail': 'Three'},
            ],
            'excellenceNotes': <Map<String, Object?>>[],
          }),
        ),
      );

      final context = tester.element(find.byIcon(Icons.priority_high));
      expect(
        find.text('${context.messages.agentFeedbackGrievancesTitle} (3)'),
        findsOneWidget,
      );
    });
  });

  group('ABComparison', () {
    testWidgets('renders question and both options', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {
            'question': 'Which tone works better during a crisis?',
            'optionA': 'We hit some hurdles but we are making progress!',
            'optionB': 'Sync reliability is below 100%. Critical failure.',
            'labelA': 'Encouraging',
            'labelB': 'Fact-first',
          }),
        ),
      );

      expect(
        find.text('Which tone works better during a crisis?'),
        findsOneWidget,
      );
      expect(
        find.text('We hit some hurdles but we are making progress!'),
        findsOneWidget,
      );
      expect(
        find.text('Sync reliability is below 100%. Critical failure.'),
        findsOneWidget,
      );
      expect(find.text('· Encouraging'), findsOneWidget);
      expect(find.text('· Fact-first'), findsOneWidget);
    });

    testWidgets('returns SizedBox when question is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {
            'question': '',
            'optionA': 'Some text',
            'optionB': 'Other text',
          }),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Some text'), findsNothing);
    });

    testWidgets('returns SizedBox when optionA is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {
            'question': 'Which?',
            'optionA': '',
            'optionB': 'Option B text',
          }),
        ),
      );

      expect(find.text('Option B text'), findsNothing);
    });

    testWidgets('returns SizedBox when optionB is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {
            'question': 'Which?',
            'optionA': 'Option A text',
            'optionB': '',
          }),
        ),
      );

      expect(find.text('Option A text'), findsNothing);
    });

    testWidgets('returns SizedBox for non-map data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {}),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('works without labels', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(abComparisonCardItem, {
            'question': 'Which?',
            'optionA': 'Phrasing A',
            'optionB': 'Phrasing B',
          }),
        ),
      );

      expect(find.text('Phrasing A'), findsOneWidget);
      expect(find.text('Phrasing B'), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
    });

    testWidgets('dispatches event on selection', (tester) async {
      final events = <UiEvent>[];
      final widget = buildCatalogWidgetWithEvents(
        abComparisonCardItem,
        {
          'question': 'Which?',
          'optionA': 'Warm phrasing.',
          'optionB': 'Direct phrasing.',
          'labelA': 'Warm',
          'labelB': 'Direct',
        },
        events: events,
      );

      await tester.pumpWidget(makeTestableWidget(widget));
      await tester.pump();

      // ABComparisonCard has no animations; selection only flips state.
      await tester.tap(find.text('Choose A'));
      await tester.pump();

      expect(events, hasLength(1));
      final event = events.first as UserActionEvent;
      expect(event.name, 'ab_comparison_submitted');

      final payload =
          jsonDecode(event.sourceComponentId) as Map<String, dynamic>;
      expect(payload['value'], contains('Option A'));
    });
  });
}
