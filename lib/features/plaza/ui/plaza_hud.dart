import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Responsive app chrome around the world. Only its controls intercept input;
/// status and navigation legends leave the street below walkable.
class PlazaHud extends StatelessWidget {
  const PlazaHud({
    required this.projectLabel,
    required this.taskCount,
    required this.weekCount,
    required this.attentionCount,
    required this.onMorningWalk,
    required this.onOverview,
    required this.onHome,
    required this.frameRate,
    required this.onFrameRateChanged,
    required this.showPenguins,
    required this.onShowPenguinsChanged,
    required this.showDebug,
    required this.onShowDebugChanged,
    this.onExit,
    this.isCategory = false,
    this.toast,
    this.walkChip,
    super.key,
  });

  final String projectLabel;
  final int taskCount;
  final int weekCount;
  final int attentionCount;
  final bool isCategory;
  final VoidCallback onMorningWalk;
  final VoidCallback onOverview;
  final VoidCallback onHome;
  final VoidCallback? onExit;
  final PlazaFrameRate frameRate;
  final ValueChanged<PlazaFrameRate> onFrameRateChanged;
  final bool showPenguins;
  final ValueChanged<bool>? onShowPenguinsChanged;
  final bool showDebug;
  final ValueChanged<bool> onShowDebugChanged;
  final String? toast;
  final String? walkChip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: tokens.spacing.step4,
                    runSpacing: tokens.spacing.step2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onExit != null)
                        DesignSystemButton(
                          label: messages.designSystemBackLabel,
                          variant: DesignSystemButtonVariant.secondary,
                          onPressed: onExit,
                        ),
                      IgnorePointer(
                        child: Text(
                          '$projectLabel — ${messages.plazaTitle}',
                          style: tokens.typography.styles.subtitle.subtitle2,
                        ),
                      ),
                      IgnorePointer(
                        child: Text(
                          isCategory
                              ? '${messages.projectCountSummary(taskCount)} · ${messages.plazaNeedsAttention(attentionCount)}'
                              : messages.plazaStats(
                                  taskCount,
                                  weekCount,
                                  attentionCount,
                                ),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DesignSystemButton(
                        label: messages.plazaMorningWalk,
                        onPressed: onMorningWalk,
                      ),
                      DesignSystemButton(
                        label: messages.plazaOverview,
                        variant: DesignSystemButtonVariant.secondary,
                        onPressed: onOverview,
                      ),
                      DesignSystemButton(
                        label: messages.designSystemBreadcrumbHomeLabel,
                        variant: DesignSystemButtonVariant.secondary,
                        onPressed: onHome,
                      ),
                      DsSegmentedToggle<PlazaFrameRate>(
                        segments: [
                          for (final rate in PlazaFrameRate.values)
                            DsSegment(
                              rate,
                              rate == PlazaFrameRate.auto
                                  ? messages.habitAutoPillLabel
                                  : rate.label,
                            ),
                        ],
                        selected: frameRate,
                        onChanged: onFrameRateChanged,
                      ),
                      DesignSystemCheckbox(
                        value: showPenguins,
                        label: messages.plazaShowPenguins,
                        onChanged: onShowPenguinsChanged == null
                            ? null
                            : (value) => onShowPenguinsChanged!(value ?? false),
                      ),
                      DesignSystemCheckbox(
                        value: showDebug,
                        label: messages.plazaDebug,
                        onChanged: (value) =>
                            onShowDebugChanged(value ?? false),
                      ),
                    ],
                  ),
                  if (toast != null)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step3),
                      child: IgnorePointer(
                        child: Center(
                          child: DsPill(
                            variant: DsPillVariant.filled,
                            shape: DsPillShape.tag,
                            label: toast,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (walkChip != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                        child: DsPill(
                          variant: DsPillVariant.filled,
                          shape: DsPillShape.tag,
                          label: walkChip,
                        ),
                      ),
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step2,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final (label, color) in [
                          (
                            messages.taskStatusInProgress,
                            PlazaStyle.lantern(LanternState.inProgress),
                          ),
                          (
                            messages.taskStatusOpen,
                            PlazaStyle.lantern(LanternState.open),
                          ),
                          (
                            messages.taskStatusBlocked,
                            PlazaStyle.lantern(LanternState.blocked),
                          ),
                          (
                            messages.projectTasksDueOverdue,
                            PlazaStyle.lantern(LanternState.overdue),
                          ),
                          (
                            messages.taskStatusDone,
                            tokens.colors.alert.success.defaultColor,
                          ),
                        ])
                          DsPill(
                            variant: DsPillVariant.tinted,
                            shape: DsPillShape.tag,
                            label: label,
                            color: color,
                          ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    Text(
                      messages.plazaControls,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
