import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

import '../../../../widget_test_utils.dart';

/// Helper to create a [ProjectStatus] variant concisely.
ProjectStatus _activeStatus() => ProjectStatus.active(
  id: 'a',
  createdAt: DateTime(2024, 3, 15),
  utcOffset: 0,
);

ProjectStatus _completedStatus() => ProjectStatus.completed(
  id: 'c',
  createdAt: DateTime(2024, 3, 15),
  utcOffset: 0,
);

ProjectStatus _archivedStatus() => ProjectStatus.archived(
  id: 'ar',
  createdAt: DateTime(2024, 3, 15),
  utcOffset: 0,
);

ProjectStatus _onHoldStatus() => ProjectStatus.onHold(
  id: 'h',
  createdAt: DateTime(2024, 3, 15),
  utcOffset: 0,
  reason: 'waiting',
);

ProjectStatus _openStatus() => ProjectStatus.open(
  id: 'o',
  createdAt: DateTime(2024, 3, 15),
  utcOffset: 0,
);

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

  group('formatCountdown', () {
    test('formats zero seconds as 0:00', () {
      expect(formatCountdown(0), '0:00');
    });

    test('formats seconds less than a minute with leading zero', () {
      expect(formatCountdown(5), '0:05');
      expect(formatCountdown(59), '0:59');
    });

    test('formats exact minutes with :00 suffix', () {
      expect(formatCountdown(60), '1:00');
      expect(formatCountdown(120), '2:00');
    });

    test('formats mixed minutes and seconds', () {
      expect(formatCountdown(90), '1:30');
      expect(formatCountdown(125), '2:05');
      expect(formatCountdown(3661), '61:01');
    });
  });

  group('showcaseUpdatedLabel', () {
    testWidgets('returns minutes label when difference is under one hour', (
      tester,
    ) async {
      late String result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              result = showcaseUpdatedLabel(
                context,
                updatedAt: DateTime(2024, 3, 15, 10),
                currentTime: DateTime(2024, 3, 15, 10, 30),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(result, contains('30m'));
      expect(result, isNot(contains('↻')));
    });

    testWidgets('returns hours label when difference >= 1 hour', (
      tester,
    ) async {
      late String result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              result = showcaseUpdatedLabel(
                context,
                updatedAt: DateTime(2024, 3, 15, 8),
                currentTime: DateTime(2024, 3, 15, 11),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(result, contains('3h'));
      expect(result, isNot(contains('↻')));
    });

    testWidgets('clamps to 1 minute when difference is under 1 minute', (
      tester,
    ) async {
      late String result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              result = showcaseUpdatedLabel(
                context,
                updatedAt: DateTime(2024, 3, 15, 10, 0, 50),
                currentTime: DateTime(2024, 3, 15, 10),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      // Negative difference => treated as <1 hour, clamped to 1 minute
      expect(result, contains('1m'));
    });

    testWidgets('returns 1 minute when updatedAt equals currentTime', (
      tester,
    ) async {
      late String result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              result = showcaseUpdatedLabel(
                context,
                updatedAt: DateTime(2024, 3, 15, 10),
                currentTime: DateTime(2024, 3, 15, 10),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(result, contains('1m'));
    });
  });

  group('CategoryTag with onTap', () {
    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          CategoryTag(
            label: 'Tappable',
            icon: Icons.label,
            color: Colors.green,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('Tappable'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not wrap in InkWell when onTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Static',
            icon: Icons.label,
            color: Colors.green,
          ),
        ),
      );
      await tester.pump();

      // No InkWell from CategoryTag (Material/InkWell not added)
      expect(
        find.ancestor(
          of: find.text('Static'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });
  });

  group('ProjectStatusPill with onTap', () {
    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          ProjectStatusPill(
            status: _activeStatus(),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('_ProjectStatusIcon via ProjectStatusLabel', () {
    testWidgets('renders SVG icon for active status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusLabel(status: _activeStatus())),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders SVG icon for completed status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusLabel(status: _completedStatus())),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('renders SVG icon for archived status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusLabel(status: _archivedStatus())),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('renders Icon fallback for onHold status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusLabel(status: _onHoldStatus())),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsNothing);
      expect(
        find.byIcon(Icons.pause_circle_outline_rounded),
        findsOneWidget,
      );
      expect(find.text('On Hold'), findsOneWidget);
    });

    testWidgets('renders Icon fallback for open status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusLabel(status: _openStatus())),
      );
      await tester.pump();

      expect(find.byType(SvgPicture), findsNothing);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('ExpandableReportSection - isRefreshing', () {
    testWidgets('shows CircularProgressIndicator when isRefreshing is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ExpandableReportSection(
            title: 'AI Report',
            body: 'Summary.',
            fullContent: 'Summary.',
            recommendations: const [],
            onRefresh: () {},
            isRefreshing: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // refresh icon should not be present while refreshing
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('hides countdown pill when isRefreshing is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ExpandableReportSection(
            title: 'AI Report',
            body: 'Summary.',
            fullContent: 'Summary.',
            recommendations: const [],
            nextWakeAt: DateTime(2024, 3, 15, 12, 5),
            onRefresh: () {},
            isRefreshing: true,
          ),
        ),
      );
      await tester.pump();

      // Countdown should be hidden while refreshing
      expect(find.byType(ShowcaseCountdownPill), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ExpandableReportSection - trailingLabel', () {
    testWidgets('renders trailing label text', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExpandableReportSection(
            title: 'AI Report',
            body: 'Summary.',
            fullContent: 'Summary.',
            recommendations: [],
            trailingLabel: 'Updated 5m ago',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Updated 5m ago'), findsOneWidget);
    });
  });

  group('ExpandableReportSection - expanded with recommendations', () {
    testWidgets('displays full content and recommendations when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ExpandableReportSection(
            title: 'AI Report',
            body: 'Short TLDR.',
            fullContent: '''
## 📋 TLDR
Short TLDR.

## Analysis
Detailed analysis section.
''',
            recommendations: ['Fix the build', 'Add tests'],
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Detailed analysis section'), findsOneWidget);
    });
  });

  group('ExpandableReportSection - empty fullContent', () {
    testWidgets('falls back to body when fullContent is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ExpandableReportSection(
            title: 'AI Report',
            body: 'Only body text here.',
            fullContent: '',
            recommendations: [],
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Only body text here'), findsOneWidget);
      // No expand icon since there's no additional content
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });
  });

  group('ShowcaseCountdownPill', () {
    testWidgets('renders the countdown text in a pill', (tester) async {
      await tester.pumpWidget(
        wrap(const ShowcaseCountdownPill(countdownText: '2:45')),
      );
      await tester.pump();

      expect(find.text('2:45'), findsOneWidget);

      // Verify it has the pill Container with minimum width
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('2:45'),
          matching: find.byType(Container),
        ),
      );
      final constraints = container.constraints;
      expect(constraints?.minWidth, 52);
    });
  });

  group('ProjectHealthBandTag - borderColor', () {
    testWidgets('renders with border color for all health bands', (
      tester,
    ) async {
      for (final band in ProjectHealthBand.values) {
        await tester.pumpWidget(
          wrap(ProjectHealthBandTag(band: band)),
        );
        await tester.pump();

        // Each band tag should render with a Container that has a border
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      }
    });
  });

  group('ProjectCreateFab', () {
    testWidgets('renders with semantic label and + icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectCreateFab(
            semanticLabel: 'Create project',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(
        find.bySemanticsLabel('Create project'),
        findsOneWidget,
      );
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        wrap(
          ProjectCreateFab(
            semanticLabel: 'Create project',
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });

  group('ProjectStatusPill - all status variants', () {
    testWidgets('renders correctly for completed status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusPill(status: _completedStatus())),
      );
      await tester.pump();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders correctly for archived status', (tester) async {
      await tester.pumpWidget(
        wrap(ProjectStatusPill(status: _archivedStatus())),
      );
      await tester.pump();

      expect(find.text('Archived'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders correctly for onHold status with Icon fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ProjectStatusPill(status: _onHoldStatus())),
      );
      await tester.pump();

      expect(find.text('On Hold'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(
        find.byIcon(Icons.pause_circle_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('renders correctly for open status with Icon fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ProjectStatusPill(status: _openStatus())),
      );
      await tester.pump();

      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
    });

    testWidgets('large + onTap renders expand chevron with InkWell', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          ProjectStatusPill(
            status: _activeStatus(),
            large: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('TaskStatePill - all status variants', () {
    testWidgets('renders in-progress status with play icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.inProgress(
              id: 'ip',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders groomed status', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.groomed(
              id: 'g',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Groomed'), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('renders on-hold status', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.onHold(
              id: 'oh',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
              reason: 'paused',
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

    testWidgets('renders done status', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.done(
              id: 'd',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(
        find.byIcon(Icons.check_circle_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('renders rejected status', (tester) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.rejected(
              id: 'r',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });
  });

  group('ExpandableReportSection - collapse/expand toggle', () {
    testWidgets('collapses from expanded state on toggle', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExpandableReportSection(
            title: 'AI Report',
            body: 'Short summary.',
            fullContent: '''
## 📋 TLDR
Short summary.

## Details
Full details here.
''',
            recommendations: [],
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pump();

      // Initially expanded - full details visible
      expect(find.textContaining('Full details here'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);

      // Collapse
      await tester.tap(find.byIcon(Icons.expand_less_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Full details here'), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });
  });

  group('ExpandableReportSection - TLDR with explicit body text', () {
    testWidgets(
      'uses body as TLDR and shows fullContent as additional when body differs',
      (tester) async {
        const fullContent =
            'Detailed report without explicit TLDR section markers.';

        await tester.pumpWidget(
          wrap(
            const ExpandableReportSection(
              title: 'Report',
              body: 'Explicit summary.',
              fullContent: fullContent,
              recommendations: [],
            ),
          ),
        );
        await tester.pump();

        // Shows explicit body as TLDR
        expect(find.textContaining('Explicit summary'), findsOneWidget);
        // Full content hidden in collapsed state
        expect(
          find.textContaining('Detailed report without explicit'),
          findsNothing,
        );

        // Has expand icon because fullContent differs from body
        expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      },
    );
  });
}
