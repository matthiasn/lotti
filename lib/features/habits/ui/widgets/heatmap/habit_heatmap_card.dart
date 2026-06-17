import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_grid.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/utils/platform.dart';

/// The consistency heatmap, wrapped in the same calm card shell as the
/// completion-rate chart: a titled, bordered surface a step lighter than the
/// page. Drives the scrollable [HabitHeatmapGrid] from
/// [habitHeatmapControllerProvider] and resolves the region's first day of week
/// from [firstDayOfWeekIndexProvider] (Monday fallback).
///
/// Shows a "less → more" legend alongside the grid, and an "add a habit"
/// placeholder when the user has no habits at all.
class HabitHeatmapCard extends ConsumerWidget {
  const HabitHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = ref.watch(habitHeatmapControllerProvider);
    final firstDayOfWeekIndex = ref
        .watch(firstDayOfWeekIndexProvider)
        .maybeWhen(data: (i) => i, orElse: () => DateTime.monday % 7);

    final showGrid = data.hasHabits && data.days.isNotEmpty;

    Widget content;
    if (data.days.isEmpty) {
      // The single pre-first-recompute frame: reserve roughly the grid's height
      // so the card doesn't jump when the data arrives.
      content = SizedBox(height: tokens.spacing.step12);
    } else if (!data.hasHabits) {
      content = _EmptyState(message: messages.habitsHeatmapEmpty);
    } else {
      content = HabitHeatmapGrid(
        columns: groupIntoWeekColumns(
          data.days,
          firstDayOfWeekIndex: firstDayOfWeekIndex,
        ),
        firstDayOfWeekIndex: firstDayOfWeekIndex,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeatmapHeader(showLegend: showGrid),
            SizedBox(height: tokens.spacing.step4),
            content,
          ],
        ),
      ),
    );
  }
}

/// The card's title + legend. On wide cards the legend sits inline on the right;
/// on a narrow card it drops to its own line beneath the title so the two never
/// crowd each other.
class _HeatmapHeader extends StatelessWidget {
  const _HeatmapHeader({required this.showLegend});

  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final title = Text(
      context.messages.habitsConsistencyTitle,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );

    if (!showLegend) {
      return title;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              SizedBox(height: tokens.spacing.step3),
              const _HeatmapLegend(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const _HeatmapLegend(),
          ],
        );
      },
    );
  }
}

/// "Less ▢▢▢▢ More" — five rounded-square swatches that exactly match the five
/// appearances a grid cell can take (empty + four intensity buckets), so the
/// colour scale is legible without hovering a cell. Each swatch carries a
/// hairline border so even the faintest steps stay visible on the card surface.
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final swatch = isDesktop ? 14.0 : 11.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(messages.habitsHeatmapLess, style: labelStyle),
        SizedBox(width: tokens.spacing.step2),
        for (final intensity in heatmapLegendIntensities) ...[
          if (intensity != heatmapLegendIntensities.first)
            SizedBox(width: tokens.spacing.step1),
          Container(
            width: swatch,
            height: swatch,
            decoration: BoxDecoration(
              color: heatmapFillColor(intensity, tokens),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
              border: Border.all(color: tokens.colors.decorative.level02),
            ),
          ),
        ],
        SizedBox(width: tokens.spacing.step2),
        Text(messages.habitsHeatmapMore, style: labelStyle),
      ],
    );
  }
}

/// Shown when the user has no habits at all — the grid would be a blank canvas,
/// so invite the first habit instead.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      height: tokens.spacing.step12,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}
