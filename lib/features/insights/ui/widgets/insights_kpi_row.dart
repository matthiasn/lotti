import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Headline numbers: plain figures in quiet tiles — no gauges, no donuts.
///
/// Until focus categories are configured only the Total tile renders,
/// alongside an affordance to pick them; dead zero tiles never ship.
class InsightsKpiRow extends StatelessWidget {
  const InsightsKpiRow({
    required this.kpis,
    required this.categories,
    required this.focusCategoryIds,
    required this.onToggleFocusCategory,
    this.previousKpis,
    this.comparisonInProgress = false,
    this.topCategoryLabel,
    this.topCategoryShare,
    super.key,
  });

  final InsightsKpis kpis;

  /// Previous-period figures when comparison is on; drives the delta chips.
  final InsightsKpis? previousKpis;

  /// Whether the current period is still unfolding. Mutes the delta colour
  /// (the change is a partial-sample preview) and annotates the baseline as
  /// "same days" so a half-finished period isn't read as a real swing.
  final bool comparisonInProgress;

  /// The largest category and its share of the total, surfaced under the Total
  /// figure so the headline answers "where did my time go", not only "how
  /// much". Null when there is nothing to rank (zero or one category).
  final String? topCategoryLabel;
  final double? topCategoryShare;

  /// Active categories, used by the focus-picker dialog.
  final List<CategoryDefinition> categories;

  final Set<String> focusCategoryIds;
  final ValueChanged<String> onToggleFocusCategory;

  Future<void> _editFocusCategories(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _FocusCategoriesDialog(
        categories: categories,
        initialSelection: focusCategoryIds,
        onToggle: onToggleFocusCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final configured = kpis.focusSeconds != null;

    // The headline answer beneath the Total figure: which category took the
    // most time, and its share.
    final topLabel = topCategoryLabel;
    final topCaption = topLabel == null
        ? null
        : messages.insightsKpiTopCategory(
            topLabel,
            formatShare(topCategoryShare ?? 0),
          );

    // The focus tile lists what it counts so it's never a black box.
    final focusNames = [
      for (final category in categories)
        if (focusCategoryIds.contains(category.id)) category.name,
    ].join(' · ');

    // Before focus is configured the Total metric leads at the same 1/3 width
    // it keeps once FOCUS/OTHER join it — never a full-width slab with 60-70%
    // dead internal space. The picker is a compact content-sized pill sitting
    // immediately beside it (left-aligned in the space the other two tiles
    // will fill), so an empty CTA never claims tile-equal weight next to the
    // one real number on screen.
    if (!configured) {
      return Row(
        children: [
          // Expanded (tight), not Flexible (loose), so the Total tile is
          // exactly 1/3 of the row — the same width it keeps once FOCUS/OTHER
          // join it — rather than shrinking toward its content.
          Expanded(
            child: _KpiTile(
              label: messages.insightsKpiTotal,
              seconds: kpis.totalSeconds,
              previousSeconds: previousKpis?.totalSeconds,
              headline: topCaption,
              inProgress: comparisonInProgress,
            ),
          ),
          SizedBox(width: tokens.spacing.cardItemSpacing),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InsightsPillButton(
                label: messages.insightsChooseFocusCategories,
                icon: Icons.center_focus_strong_outlined,
                active: false,
                outlined: true,
                onTap: () => _editFocusCategories(context),
              ),
            ),
          ),
        ],
      );
    }

    // IntrinsicHeight equalizes tile heights inside the unbounded-height
    // ListView (a bare stretch Row would receive infinite constraints).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _KpiTile(
              label: messages.insightsKpiTotal,
              seconds: kpis.totalSeconds,
              previousSeconds: previousKpis?.totalSeconds,
              headline: topCaption,
              inProgress: comparisonInProgress,
            ),
          ),
          SizedBox(width: tokens.spacing.cardItemSpacing),
          Expanded(
            child: _KpiTile(
              label: messages.insightsKpiFocus,
              seconds: kpis.focusSeconds!,
              previousSeconds: previousKpis?.focusSeconds,
              // Plain-language gloss so FOCUS/OTHER aren't opaque jargon to a
              // first-time user; the category names follow as the detail.
              helper: messages.insightsKpiFocusHelp,
              caption: focusNames,
              onEdit: () => _editFocusCategories(context),
              inProgress: comparisonInProgress,
            ),
          ),
          SizedBox(width: tokens.spacing.cardItemSpacing),
          Expanded(
            child: _KpiTile(
              label: messages.insightsKpiOther,
              seconds: kpis.otherSeconds!,
              previousSeconds: previousKpis?.otherSeconds,
              helper: messages.insightsKpiOtherHelp,
              inProgress: comparisonInProgress,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.seconds,
    this.previousSeconds,
    this.headline,
    this.helper,
    this.caption,
    this.onEdit,
    this.inProgress = false,
  });

  final String label;
  final int seconds;

  /// Previous-period seconds for the delta chip; null hides comparison.
  final int? previousSeconds;

  /// Load-bearing line under the figure — the "where it went" answer (e.g.
  /// "Most on Client Work · 40%"). Rendered a tier above [caption] so the
  /// insight, not the vanity total, carries the tile.
  final String? headline;

  /// Plain-language gloss of what the tile counts (e.g. "Everything else" on
  /// the OTHER tile), so the terse eyebrow label isn't opaque to newcomers.
  final String? helper;

  /// Quiet single-line annotation under the number (e.g. the focus
  /// category names).
  final String? caption;
  final VoidCallback? onEdit;

  /// In-progress comparison: annotates the baseline as "same days" (vs "full
  /// period" for a completed range) so a partial comparison reads honestly.
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Local copy so flow analysis promotes it inside the null check — a
    // public field can't be promoted directly, which is why the delta block
    // below would otherwise need `!`.
    final previousSeconds = this.previousSeconds;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insightsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    // mediumEmphasis: the default lowEmphasis eyebrow is
                    // near-illegible on the light theme (32% black).
                    style: calmEyebrowStyle(
                      tokens,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  _InlineIconButton(
                    icon: Icons.tune_rounded,
                    onTap: onEdit!,
                    semanticsLabel:
                        context.messages.insightsChooseFocusCategories,
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              // Rolls into days at quarter/year scale so a ~1000h headline
              // stays legible; below 100h this is the familiar "3h 40m".
              formatDurationWithDays(seconds),
              style: calmDisplayStyle(tokens),
            ),
            // In compare mode the trend leads: the signed delta is the second
            // beat directly under the figure, then the "where it went" line,
            // then the baseline+basis trailing smallest.
            if (previousSeconds != null) ...[
              SizedBox(height: tokens.spacing.step2),
              InsightsDeltaChip(
                current: seconds,
                previous: previousSeconds,
                prominent: true,
              ),
            ],
            if (headline != null && headline!.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                headline!,
                // The answer to "where did my time go", in high-emphasis body.
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (previousSeconds != null) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                // The baseline + comparison basis trails the delta: same
                // elapsed days while in progress, the whole period once done.
                '${context.messages.insightsCompareVs} '
                '${formatDurationWithDays(previousSeconds)}'
                ' · '
                '${inProgress ? context.messages.insightsCompareSameDays : context.messages.insightsCompareFullPeriod}',
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (helper != null && helper!.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                helper!,
                // mediumEmphasis: the gloss is for orientation, a notch more
                // present than the detail caption below it.
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (caption != null && caption!.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                caption!,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineIconButton extends StatelessWidget {
  const _InlineIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          child: Icon(
            icon,
            size: tokens.spacing.step5,
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}

class _FocusCategoriesDialog extends StatefulWidget {
  const _FocusCategoriesDialog({
    required this.categories,
    required this.initialSelection,
    required this.onToggle,
  });

  final List<CategoryDefinition> categories;
  final Set<String> initialSelection;
  final ValueChanged<String> onToggle;

  @override
  State<_FocusCategoriesDialog> createState() => _FocusCategoriesDialogState();
}

class _FocusCategoriesDialogState extends State<_FocusCategoriesDialog> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return AlertDialog(
      backgroundColor: insightsCardSurface(context),
      title: Text(
        messages.insightsFocusCategoriesTitle,
        style: tokens.typography.styles.heading.heading3,
      ),
      content: SizedBox(
        width: tokens.spacing.step13 * 2,
        child: widget.categories.isEmpty
            ? Text(
                messages.insightsFocusCategoriesEmpty,
                style: tokens.typography.styles.body.bodySmall,
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final category in widget.categories)
                    CheckboxListTile(
                      value: _selected.contains(category.id),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        category.name,
                        style: tokens.typography.styles.body.bodyMedium,
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (!_selected.remove(category.id)) {
                            _selected.add(category.id);
                          }
                        });
                        widget.onToggle(category.id);
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(messages.doneButton),
        ),
      ],
    );
  }
}
