import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  Finder rootContainer(Finder widgetFinder) {
    return find.descendant(
      of: widgetFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.child is Row,
      ),
    );
  }

  group('Task showcase shared widgets', () {
    testWidgets('renders compact task detail chip heights', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TaskShowcaseCategoryChip(
                label: 'Work',
                icon: Icons.work_rounded,
                colorHex: '#4AB6E8',
              ),
              const SizedBox(height: 8),
              const TaskShowcaseMetaChip(
                icon: Icons.watch_later_outlined,
                label: 'Due: Apr 1, 2026',
              ),
              const SizedBox(height: 8),
              const TaskShowcaseLabelChip(
                label: 'Bug fix',
                color: Colors.blue,
                outlined: true,
              ),
              const SizedBox(height: 8),
              const TaskShowcaseSectionPill(
                icon: Icons.timer_outlined,
                label: 'Timer',
                active: true,
              ),
              const SizedBox(height: 8),
              TaskShowcaseStatusLabel(
                status: TaskStatus.open(
                  id: 'open',
                  createdAt: DateTime(2024),
                  utcOffset: 0,
                ),
                expanded: true,
              ),
            ],
          ),
        ),
      );

      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseCategoryChip, 'Work'),
              ),
            )
            .height,
        18,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseMetaChip, 'Due: Apr 1, 2026'),
              ),
            )
            .height,
        20,
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.widgetWithText(TaskShowcaseLabelChip, 'Bug fix'),
                matching: find.byType(Container),
              ),
            )
            .height,
        20,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseSectionPill, 'Timer'),
              ),
            )
            .height,
        24,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseStatusLabel, 'Open'),
              ),
            )
            .height,
        28,
      );
    });

    testWidgets('renders TaskShowcaseStatusGlyph for all status types', (
      tester,
    ) async {
      final statuses = [
        TaskStatus.open(id: 's1', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.groomed(id: 's2', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.inProgress(
          id: 's3',
          createdAt: DateTime(2024),
          utcOffset: 0,
        ),
        TaskStatus.blocked(
          id: 's4',
          createdAt: DateTime(2024),
          utcOffset: 0,
          reason: 'blocked',
        ),
        TaskStatus.onHold(
          id: 's5',
          createdAt: DateTime(2024),
          utcOffset: 0,
          reason: 'on hold',
        ),
        TaskStatus.done(id: 's6', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.rejected(id: 's7', createdAt: DateTime(2024), utcOffset: 0),
      ];

      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in statuses)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: TaskShowcaseStatusGlyph(status: status),
                ),
            ],
          ),
        ),
      );

      expect(
        find.byType(TaskShowcaseStatusGlyph),
        findsNWidgets(statuses.length),
      );
    });

    testWidgets('TaskShowcasePriorityGlyph picks the priority-specific asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskShowcasePriorityGlyph(priority: TaskPriority.p0Urgent),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p1High),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p2Medium),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p3Low),
            ],
          ),
        ),
      );

      const expectedAssets = {
        TaskPriority.p0Urgent: 'assets/design_system/task_priority_p0.svg',
        TaskPriority.p1High: 'assets/design_system/task_priority_high.svg',
        TaskPriority.p2Medium: 'assets/design_system/task_priority_medium.svg',
        TaskPriority.p3Low: 'assets/design_system/task_priority_low.svg',
      };

      for (final entry in expectedAssets.entries) {
        final svg = tester.widget<SvgPicture>(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is TaskShowcasePriorityGlyph &&
                  widget.priority == entry.key,
            ),
            matching: find.byType(SvgPicture),
          ),
        );
        expect(
          (svg.bytesLoader as SvgAssetLoader).assetName,
          entry.value,
          reason: 'asset for ${entry.key}',
        );
      }
    });

    testWidgets(
      'TaskShowcaseSectionPill switches colors between active and inactive',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaskShowcaseSectionPill(
                  icon: Icons.timer_outlined,
                  label: 'Active',
                  active: true,
                ),
                SizedBox(height: 8),
                TaskShowcaseSectionPill(
                  icon: Icons.timer_outlined,
                  label: 'Inactive',
                ),
              ],
            ),
          ),
        );

        final context = tester.element(
          find.widgetWithText(TaskShowcaseSectionPill, 'Active'),
        );

        Color pillColor(String label) {
          final container = tester.widget<Container>(
            rootContainer(find.widgetWithText(TaskShowcaseSectionPill, label)),
          );
          return (container.decoration! as BoxDecoration).color!;
        }

        Color iconColor(String label) => tester
            .widget<Icon>(
              find.descendant(
                of: find.widgetWithText(TaskShowcaseSectionPill, label),
                matching: find.byType(Icon),
              ),
            )
            .color!;

        // Active: accent fill with forced-black foreground for contrast.
        expect(pillColor('Active'), TaskShowcasePalette.accent(context));
        expect(iconColor('Active'), Colors.black);

        // Inactive: subtle fill with medium-emphasis foreground.
        expect(pillColor('Inactive'), TaskShowcasePalette.subtleFill(context));
        expect(iconColor('Inactive'), TaskShowcasePalette.mediumText(context));
      },
    );

    testWidgets('TaskShowcaseHeroBanner honours height and paints the bridge', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 360,
            child: TaskShowcaseHeroBanner(height: 140),
          ),
        ),
      );

      expect(tester.getSize(find.byType(TaskShowcaseHeroBanner)).height, 140);

      // The decorative handshake bridge is painted via a CustomPaint.
      expect(
        find.descendant(
          of: find.byType(TaskShowcaseHeroBanner),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // The outer gradient surface is clipped with the large token radius.
      final context = tester.element(find.byType(TaskShowcaseHeroBanner));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(TaskShowcaseHeroBanner),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(
        clip.borderRadius,
        BorderRadius.circular(context.designTokens.radii.l),
      );
    });

    testWidgets('TaskShowcaseWaveform scales bar heights from samples', (
      tester,
    ) async {
      const samples = [0.0, 0.5, 1.0];
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 300,
            child: TaskShowcaseWaveform(samples: samples),
          ),
        ),
      );

      final bars = find.descendant(
        of: find.byType(TaskShowcaseWaveform),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(999),
        ),
      );

      // One bar per sample, each 8px tall plus 24px scaled by the sample.
      expect(bars, findsNWidgets(samples.length));
      for (var index = 0; index < samples.length; index++) {
        expect(
          tester.getSize(bars.at(index)).height,
          8 + samples[index] * 24,
          reason: 'bar height for sample ${samples[index]}',
        );
      }
    });

    testWidgets(
      'TaskShowcaseDesktopActionBar renders timer pill, round actions, and FAB',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const SizedBox(width: 800, child: TaskShowcaseDesktopActionBar()),
          ),
        );

        final context = tester.element(
          find.byType(TaskShowcaseDesktopActionBar),
        );
        expect(find.text(context.messages.addActionAddTimer), findsOneWidget);

        for (final icon in const [
          Icons.checklist_rounded,
          Icons.image_outlined,
          Icons.mic_none_rounded,
          Icons.subdirectory_arrow_right_rounded,
        ]) {
          expect(
            find.descendant(
              of: find.byType(TaskShowcaseDesktopActionBar),
              matching: find.byIcon(icon),
            ),
            findsOneWidget,
            reason: 'round action $icon',
          );
        }

        expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      },
    );
  });
}
