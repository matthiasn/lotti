import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
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

  group('ProjectHealthBandTag', () {
    testWidgets('renders the health band label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ProjectHealthBandTag(
            band: ProjectHealthBand.atRisk,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('At Risk'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
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
      expect(find.byType(SvgPicture), findsOneWidget);
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

    testWidgets('matches the category tag height in compact mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Row(
            children: [
              const CategoryTag(
                label: 'Work',
                icon: Icons.work,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              ProjectStatusPill(
                status: ProjectStatus.active(
                  id: 'a',
                  createdAt: DateTime(2026),
                  utcOffset: 0,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final categorySize = tester.getSize(find.byType(CategoryTag));
      final statusSize = tester.getSize(find.byType(ProjectStatusPill));

      expect(statusSize.height, categorySize.height);
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

    testWidgets('uses the Figma body-small status typography', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectStatusLabel(
            status: ProjectStatus.active(
              id: 'a',
              createdAt: DateTime(2026),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Active'));

      expect(label.style?.fontSize, 14);
      expect(label.style?.fontWeight, FontWeight.w400);
      expect(label.style?.height, closeTo(1.4286, 0.0001));
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

  group('ExpandableReportSection', () {
    testWidgets(
      'starts collapsed on the TLDR and expands to the full report body without repeating the TLDR section',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ExpandableReportSection(
              title: 'AI Report',
              body: 'TLDR only.',
              fullContent: '''
## 📋 TLDR
TLDR only.

## Details
Longer report content.
''',
              recommendations: ['Ship the fix'],
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('TLDR only'), findsOneWidget);
        expect(find.textContaining('Longer report content'), findsNothing);
        expect(find.text('Recommendations'), findsNothing);
        expect(find.text('Ship the fix'), findsNothing);

        await tester.tap(find.byIcon(Icons.expand_more_rounded));
        await tester.pumpAndSettle();

        expect(find.textContaining('Longer report content'), findsOneWidget);
        expect(find.text('TLDR'), findsNothing);
      },
    );

    testWidgets(
      'does not show an expand affordance when only the summary is available',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ExpandableReportSection(
              title: 'AI Report',
              body: 'TLDR only.',
              fullContent: 'TLDR only.',
              recommendations: ['Ship the fix'],
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
        expect(find.text('Recommendations'), findsNothing);
        expect(find.text('Ship the fix'), findsNothing);
      },
    );

    testWidgets(
      'derives the collapsed TLDR from full markdown when the body matches the full content',
      (tester) async {
        const fullReport = '''
## 📋 TLDR
Short summary.

## Details
Longer report content.
''';

        await tester.pumpWidget(
          wrap(
            const ExpandableReportSection(
              title: 'AI Report',
              body: fullReport,
              fullContent: fullReport,
              recommendations: [],
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Short summary'), findsOneWidget);
        expect(find.textContaining('Longer report content'), findsNothing);
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'shows an expand affordance and renders the full report when the body is a separate summary',
      (tester) async {
        const fullReport =
            'Full report body with more context.\n\nSecond paragraph.';

        await tester.pumpWidget(
          wrap(
            const ExpandableReportSection(
              title: 'AI Report',
              body: 'Short summary.',
              fullContent: fullReport,
              recommendations: [],
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Short summary'), findsOneWidget);
        expect(
          find.textContaining('Full report body with more context'),
          findsNothing,
        );
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.expand_more_rounded));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Full report body with more context'),
          findsOneWidget,
        );
      },
    );

    testWidgets('invokes refresh callback when refresh icon is tapped', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        wrap(
          ExpandableReportSection(
            title: 'AI Report',
            body: 'TLDR only.',
            fullContent: 'TLDR only.',
            recommendations: const [],
            onRefresh: () => refreshCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();

      expect(refreshCount, 1);
    });

    testWidgets('renders a countdown pill when the next run is scheduled', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ExpandableReportSection(
            title: 'AI Report',
            body: 'TLDR only.',
            fullContent: 'TLDR only.',
            recommendations: const [],
            nextWakeAt: DateTime.now().add(const Duration(minutes: 2)),
            onRefresh: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShowcaseCountdownPill), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
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

  group('ShowcasePanel', () {
    testWidgets('renders header, dividers between items, and all items', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ShowcasePanel(
            header: const Text('Panel Title'),
            itemCount: 3,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Item $index'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Panel Title'), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      // 1 divider below header + 2 dividers between 3 items = 3 total
      expect(find.byType(Divider), findsNWidgets(3));
    });

    testWidgets('renders only header divider when itemCount is zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ShowcasePanel(
            header: const Text('Empty'),
            itemCount: 0,
            itemBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Empty'), findsOneWidget);
      // Only the header divider
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders no inter-item divider for a single item', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ShowcasePanel(
            header: const Text('Solo'),
            itemCount: 1,
            itemBuilder: (_, _) => const Text('Only item'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Only item'), findsOneWidget);
      // 1 divider below header, 0 between items
      expect(find.byType(Divider), findsOneWidget);
    });
  });
}
