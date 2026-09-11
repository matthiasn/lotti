import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/features/plaza/ui/plaza_top_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Responsive app chrome around the world. Only its controls intercept input;
/// status and navigation legends leave the street below walkable.
///
/// The controls live inside [PlazaTopBar], which hides them behind a toggle
/// so the street keeps the top of the screen. Everything that is *not* a
/// control — the toast, the status key, the keyboard legend — stays on
/// screen whatever the toolbar is doing: a message nobody can see is not a
/// message.
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
    required this.skyMode,
    required this.onSkyModeChanged,
    required this.showPenguins,
    required this.onShowPenguinsChanged,
    required this.showMeerkats,
    required this.onShowMeerkatsChanged,
    required this.showDebug,
    required this.onShowDebugChanged,
    required this.toolbarOpen,
    required this.onToolbarToggle,
    this.onExit,
    this.palette = PlazaPalette.night,
    this.showConnections = true,
    this.onShowConnectionsChanged,
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
  final bool showConnections;
  final ValueChanged<bool>? onShowConnectionsChanged;
  final PlazaFrameRate frameRate;
  final ValueChanged<PlazaFrameRate> onFrameRateChanged;

  /// Whether the tools are showing. Held by the renderer, because the `T`
  /// key throws the same switch and only the renderer sees the keyboard.
  final bool toolbarOpen;
  final VoidCallback onToolbarToggle;

  /// The sky the world is under, and the control that changes it.
  final PlazaSkyMode skyMode;
  final ValueChanged<PlazaSkyMode> onSkyModeChanged;

  /// The active palette. The status legend reads its lantern colours from
  /// here, so the key under the street always shows the colours the roofs
  /// are actually wearing.
  final PlazaPalette palette;
  final bool showMeerkats;
  final ValueChanged<bool>? onShowMeerkatsChanged;
  final bool showPenguins;
  final ValueChanged<bool>? onShowPenguinsChanged;
  final bool showDebug;
  final ValueChanged<bool> onShowDebugChanged;
  final String? toast;
  final String? walkChip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlazaTopBar(
                    open: toolbarOpen,
                    onToggle: onToolbarToggle,
                    onExit: onExit,
                    toolbar: _toolbar(context),
                  ),
                  if (toast != null)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step3),
                      child: IgnorePointer(
                        child: DsPill(
                          variant: DsPillVariant.filled,
                          shape: DsPillShape.tag,
                          label: toast,
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
                child: _Legible(
                  palette: palette,
                  child: _legend(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the toggle reveals: who and how much, then everything pressable.
  Widget _toolbar(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
                    : messages.plazaStats(taskCount, weekCount, attentionCount),
                style: tokens.typography.styles.others.caption.copyWith(
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
            DsSegmentedToggle<PlazaSkyMode>(
              segments: [
                DsSegment(PlazaSkyMode.night, messages.plazaSkyNight),
                DsSegment(PlazaSkyMode.day, messages.plazaSkyDay),
              ],
              selected: skyMode,
              onChanged: onSkyModeChanged,
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
            if (onShowConnectionsChanged != null)
              DesignSystemCheckbox(
                value: showConnections,
                label: messages.knowledgeGraphViewConnections,
                onChanged: (value) => onShowConnectionsChanged!(value ?? false),
              ),
            DesignSystemCheckbox(
              value: showMeerkats,
              label: messages.plazaMeerkats,
              onChanged: onShowMeerkatsChanged == null
                  ? null
                  : (value) => onShowMeerkatsChanged!(value ?? false),
            ),
            DesignSystemCheckbox(
              value: showDebug,
              label: messages.plazaDebug,
              onChanged: (value) => onShowDebugChanged(value ?? false),
            ),
          ],
        ),
      ],
    );
  }

  /// The status key and the keyboard legend, under the street.
  Widget _legend(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
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
                palette.lanterns.of(LanternState.inProgress),
              ),
              (messages.taskStatusOpen, palette.lanterns.of(LanternState.open)),
              (
                messages.taskStatusBlocked,
                palette.lanterns.of(LanternState.blocked),
              ),
              (
                messages.projectTasksDueOverdue,
                palette.lanterns.of(LanternState.overdue),
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
    );
  }
}

/// Keeps the HUD readable over whatever the world is doing behind it.
///
/// The legend is dark: white type and tinted status pills, drawn straight
/// onto the scene. Against a night street that works — the street is
/// darker than the type. Against a sunlit one it does not, so daylight
/// puts the legend on a scrim and night leaves the view unobstructed.
///
/// The toolbar above needs none of this: it brings its own glass.
class _Legible extends StatelessWidget {
  const _Legible({required this.palette, required this.child});

  final PlazaPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!palette.isDay) return child;
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PlazaStyle.panel.withValues(alpha: SurfaceAlphas.linework),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step2,
        ),
        child: child,
      ),
    );
  }
}
