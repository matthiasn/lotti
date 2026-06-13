import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
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
    super.key,
  });

  final InsightsKpis kpis;

  /// Previous-period figures when comparison is on; drives the delta chips.
  final InsightsKpis? previousKpis;

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

    // The focus tile lists what it counts so it's never a black box.
    final focusNames = [
      for (final category in categories)
        if (focusCategoryIds.contains(category.id)) category.name,
    ].join(' · ');

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
            ),
          ),
          if (configured) ...[
            SizedBox(width: tokens.spacing.cardItemSpacing),
            Expanded(
              child: _KpiTile(
                label: messages.insightsKpiFocus,
                seconds: kpis.focusSeconds!,
                previousSeconds: previousKpis?.focusSeconds,
                caption: focusNames,
                onEdit: () => _editFocusCategories(context),
              ),
            ),
            SizedBox(width: tokens.spacing.cardItemSpacing),
            Expanded(
              child: _KpiTile(
                label: messages.insightsKpiOther,
                seconds: kpis.otherSeconds!,
                previousSeconds: previousKpis?.otherSeconds,
              ),
            ),
          ] else ...[
            SizedBox(width: tokens.spacing.cardItemSpacing),
            // The affordance occupies the focus+other footprint so the row
            // reads as a deliberate 2-up, not a truncated 3-up.
            Expanded(
              flex: 2,
              child: _ChooseFocusTile(
                onTap: () => _editFocusCategories(context),
              ),
            ),
          ],
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
    this.caption,
    this.onEdit,
  });

  final String label;
  final int seconds;

  /// Previous-period seconds for the delta chip; null hides comparison.
  final int? previousSeconds;

  /// Quiet single-line annotation under the number (e.g. the focus
  /// category names).
  final String? caption;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Local copy so flow analysis promotes it inside the null check — a
    // public field can't be promoted directly, which is why the delta block
    // below would otherwise need `!`.
    final previousSeconds = this.previousSeconds;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
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
              formatDurationCompact(seconds),
              style: calmDisplayStyle(tokens),
            ),
            if (previousSeconds != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Row(
                children: [
                  InsightsDeltaChip(
                    current: seconds,
                    previous: previousSeconds,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Flexible(
                    child: Text(
                      '${context.messages.insightsCompareVs} '
                      '${formatDurationCompact(previousSeconds)}',
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (caption != null && caption!.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
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

class _ChooseFocusTile extends StatelessWidget {
  const _ChooseFocusTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        hoverColor: tokens.colors.surface.hover,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.cardPadding),
            child: Row(
              children: [
                Icon(
                  Icons.center_focus_strong_outlined,
                  size: tokens.spacing.step6,
                  color: tokens.colors.text.lowEmphasis,
                ),
                SizedBox(width: tokens.spacing.step4),
                Flexible(
                  child: Text(
                    context.messages.insightsChooseFocusCategories,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      backgroundColor: tokens.colors.background.level02,
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
