import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';

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
  Widget wrap(
    Widget child, {
    bool tickerModeEnabled = true,
  }) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: TickerMode(
            enabled: tickerModeEnabled,
            child: child,
          ),
        ),
      ),
    );
  }

  group('CategoryTag', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Work',
            icon: LottiIcons.work,
            color: Colors.blue,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.byIcon(LottiIcons.work), findsOneWidget);
    });

    testWidgets('uses white text on a near-black background', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Ollama',
            icon: LottiIcons.computer,
            // Seeded "Ollama Charcoal" (#0F172A) — the case that prompted
            // the contrast-aware foreground flip.
            color: Color(0xFF0F172A),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Ollama'));
      expect(label.style?.color, equals(Colors.white));
      final iconWidget = tester.widget<Icon>(find.byIcon(LottiIcons.computer));
      expect(iconWidget.color, equals(Colors.white));
    });

    testWidgets('uses black text on a near-white background', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CategoryTag(
            label: 'Pale',
            icon: LottiIcons.label,
            color: Color(0xFFF8FAFC),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Pale'));
      expect(label.style?.color, equals(Colors.black));
    });
  });

  group('OutlinedMetaTag', () {
    testWidgets(
      'placeholder vs regular style: placeholder uses the medium-text '
      'palette color, regular uses low-text',
      (tester) async {
        for (final isPlaceholder in [true, false]) {
          await tester.pumpWidget(
            wrap(
              OutlinedMetaTag(
                icon: LottiIcons.folder,
                label: 'No category',
                isPlaceholder: isPlaceholder,
              ),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(OutlinedMetaTag));
          final expectedColor = isPlaceholder
              ? ShowcasePalette.mediumText(context)
              : ShowcasePalette.lowText(context);
          final label = tester.widget<Text>(find.text('No category'));
          expect(
            label.style?.color,
            expectedColor,
            reason: 'isPlaceholder=$isPlaceholder',
          );
          final icon = tester.widget<Icon>(find.byIcon(LottiIcons.folder));
          expect(
            icon.color,
            expectedColor,
            reason: 'isPlaceholder=$isPlaceholder',
          );
        }
      },
    );

    testWidgets('without onTap renders no InkWell', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OutlinedMetaTag(
            icon: LottiIcons.folder,
            label: 'Static tag',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('with onTap renders an InkWell and forwards the tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          OutlinedMetaTag(
            icon: LottiIcons.folder,
            label: 'Tappable tag',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(OutlinedMetaTag));
      expect(taps, 1);
    });

    testWidgets('interactive tags stay shrink-wrapped inside a Wrap', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Wrap(
            children: [
              OutlinedMetaTag(
                icon: LottiIcons.folder,
                label: 'Category',
                onTap: () {},
              ),
              OutlinedMetaTag(
                icon: LottiIcons.today,
                label: 'Target date',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getCenter(find.text('Category')).dy,
        tester.getCenter(find.text('Target date')).dy,
      );
      expect(
        tester.getSize(find.byType(OutlinedMetaTag).first).width,
        lessThan(200),
      );
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
      expect(find.byIcon(LottiIcons.warning), findsOneWidget);
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

      expect(find.byIcon(LottiIcons.expandBoth), findsOneWidget);
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

      expect(find.byIcon(LottiIcons.expandBoth), findsNothing);
    });

    testWidgets('uses the shared task metadata pill height in compact mode', (
      tester,
    ) async {
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

      final statusSize = tester.getSize(find.byType(ProjectStatusPill));

      expect(find.byType(DsPill), findsOneWidget);
      expect(statusSize.height, DsPill.height);
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
        find.byIcon(LottiIcons.pauseCircled),
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(TaskStatePill));

      expect(find.text('Open'), findsOneWidget);
      expect(loader.assetName, 'assets/design_system/task_status_open.svg');
      expect(
        svg.colorFilter,
        equals(
          ColorFilter.mode(
            ShowcasePalette.mediumText(context),
            BlendMode.srcIn,
          ),
        ),
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(TaskStatePill));

      expect(find.text('Blocked'), findsOneWidget);
      expect(loader.assetName, 'assets/design_system/task_status_blocked.svg');
      expect(
        svg.colorFilter,
        equals(
          ColorFilter.mode(
            ShowcasePalette.error(context),
            BlendMode.srcIn,
          ),
        ),
      );
    });

    testWidgets('renders plain icon-plus-label styling without a filled pill', (
      tester,
    ) async {
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

      final label = tester.widget<Text>(find.text('Open'));

      expect(find.byType(Container), findsNothing);
      expect(label.style?.fontSize, 14);
      expect(label.style?.fontWeight, FontWeight.w400);
      expect(label.style?.height, closeTo(1.4286, 0.0001));
    });

    testWidgets('uses the compact metadata styling in compact mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TaskStatePill(
            status: TaskStatus.onHold(
              id: 'h',
              createdAt: DateTime(2026),
              utcOffset: 0,
              reason: 'waiting',
            ),
            compact: true,
          ),
        ),
      );
      await tester.pump();

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final label = tester.widget<Text>(find.text('On Hold'));
      final context = tester.element(find.byType(TaskStatePill));

      expect(svg.width, 16);
      expect(svg.height, 16);
      expect(label.style?.fontSize, 14);
      expect(label.style?.fontWeight, FontWeight.w400);
      expect(label.style?.height, closeTo(1.4286, 0.0001));
      expect(label.style?.color, ShowcasePalette.lowText(context));
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

  group('CategoryTag with onTap', () {
    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          CategoryTag(
            label: 'Tappable',
            icon: LottiIcons.label,
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
            icon: LottiIcons.label,
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
        find.byIcon(LottiIcons.pauseCircled),
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
        find.byIcon(LottiIcons.radioUnselected),
        findsOneWidget,
      );
      expect(find.text('Open'), findsOneWidget);
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
        find.byIcon(LottiIcons.pauseCircled),
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
        find.byIcon(LottiIcons.radioUnselected),
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

      expect(find.byIcon(LottiIcons.expandBoth), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('TaskStatePill - all status variants', () {
    testWidgets('renders in-progress status with colored active glyph', (
      tester,
    ) async {
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(TaskStatePill));

      expect(find.text('In Progress'), findsOneWidget);
      expect(
        loader.assetName,
        'assets/design_system/project_status_active.svg',
      );
      expect(
        svg.colorFilter,
        equals(
          ColorFilter.mode(
            ShowcasePalette.amber(context),
            BlendMode.srcIn,
          ),
        ),
      );
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;

      expect(find.text('Groomed'), findsOneWidget);
      expect(loader.assetName, 'assets/design_system/task_status_groomed.svg');
    });

    testWidgets('renders on-hold status with colored pause glyph', (
      tester,
    ) async {
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(TaskStatePill));

      expect(find.text('On Hold'), findsOneWidget);
      expect(
        loader.assetName,
        'assets/design_system/task_status_on_hold.svg',
      );
      expect(
        svg.colorFilter,
        equals(
          ColorFilter.mode(
            ShowcasePalette.amber(context),
            BlendMode.srcIn,
          ),
        ),
      );
    });

    testWidgets('renders done status with colored completed glyph', (
      tester,
    ) async {
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

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(TaskStatePill));

      expect(find.text('Done'), findsOneWidget);
      expect(
        loader.assetName,
        'assets/design_system/project_status_completed.svg',
      );
      expect(
        svg.colorFilter,
        equals(
          ColorFilter.mode(
            ShowcasePalette.timeGreen(context),
            BlendMode.srcIn,
          ),
        ),
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
      expect(find.byIcon(LottiIcons.closeCircled), findsOneWidget);
    });
  });
}
