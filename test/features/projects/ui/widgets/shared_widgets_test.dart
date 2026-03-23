import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(body: child),
      ),
    );
  }

  group('CategoryTag', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Work',
            icon: Icons.work,
            color: Colors.blue,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.byIcon(Icons.work), findsOneWidget);
    });
  });

  group('ProjectStatusPill', () {
    testWidgets('renders status label and icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectStatusPill(
            status: ProjectStatus.active(
              id: 'a',
              createdAt: DateTime(2026),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders expand chevron when large', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectStatusPill(
            status: ProjectStatus.active(
              id: 'a',
              createdAt: DateTime(2026),
              utcOffset: 0,
            ),
            large: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('omits expand chevron when not large', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectStatusPill(
            status: ProjectStatus.completed(
              id: 'c',
              createdAt: DateTime(2026),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);
    });
  });

  group('ProjectStatusLabel', () {
    testWidgets('renders icon and text for each status', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectStatusLabel(
            status: ProjectStatus.onHold(
              id: 'h',
              createdAt: DateTime(2026),
              utcOffset: 0,
              reason: 'waiting',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('On Hold'), findsOneWidget);
      expect(
        find.byIcon(Icons.pause_circle_outline_rounded),
        findsOneWidget,
      );
    });
  });

  group('TaskStatePill', () {
    testWidgets('renders localised label for open task', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.open(
              id: 't',
              createdAt: DateTime(2026),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open'), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
    });

    testWidgets('renders blocked status with warning icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.blocked(
              id: 'b',
              createdAt: DateTime(2026),
              utcOffset: 0,
              reason: 'test',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('CountDotBadge', () {
    testWidgets('renders the count value', (tester) async {
      await tester.pumpWidget(wrap(const CountDotBadge(count: 7)));
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
    });
  });

  group('NoResultsPane', () {
    testWidgets('renders no-results message', (tester) async {
      await tester.pumpWidget(wrap(const NoResultsPane()));
      await tester.pump();

      expect(find.text('No projects match your search.'), findsOneWidget);
    });
  });

  group('TextSection', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TextSection(
            title: 'Description',
            body: 'Some text here.',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Some text here.'), findsOneWidget);
    });

    testWidgets('renders trailing label when provided', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TextSection(
            title: 'Report',
            body: 'Content.',
            trailingLabel: 'Updated 2h ago',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Updated 2h ago'), findsOneWidget);
    });

    testWidgets('omits trailing label when null', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TextSection(title: 'Title', body: 'Body'),
        ),
      );
      await tester.pump();

      // Only title and body text widgets
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });

  group('RecommendationsList', () {
    testWidgets('renders bullet items', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RecommendationsList(
            items: ['Do this', 'Do that'],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Do this'), findsOneWidget);
      expect(find.text('Do that'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('renders empty when no items', (tester) async {
      await tester.pumpWidget(
        wrap(const RecommendationsList(items: [])),
      );
      await tester.pump();

      expect(find.text('•'), findsNothing);
    });
  });
}
