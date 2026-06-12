import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// Text scale at which the bar stacks its pills vertically instead of
/// laying them out in one row. Mirrors the daily-OS planning bar policy
/// (`kDailyOsStackBarPillsScale`): at large accessibility scales two
/// labeled pills no longer fit side by side on a phone.
const double _stackPillsTextScale = 1.5;

/// Sticky glass action bar shared by every settings definition detail page
/// (categories, labels, habits, measurables, dashboards).
///
/// Built on [DesignSystemGlassStrip] (hairline + backdrop blur + scrim), so
/// page content scrolls visibly behind it — hosts must mount it as
/// `Scaffold.bottomNavigationBar` with `extendBody: true` (handled by
/// `SettingsDetailScaffold`).
///
/// Layout: destructive action far start, primary/secondary pills at the end
/// of the shared content column ([SettingsContentArea]), so the save button
/// lines up with the form fields' right edge at every pane width. At large
/// accessibility text scales the actions stack vertically with the primary
/// action closest to the thumb.
class SettingsFormActionBar extends StatelessWidget {
  const SettingsFormActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.check_rounded,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.destructiveLabel,
    this.onDestructive,
    this.destructiveEnabled = true,
    super.key,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'secondaryLabel and onSecondary must be provided together.',
       ),
       assert(
         (destructiveLabel == null) == (onDestructive == null),
         'destructiveLabel and onDestructive must be provided together.',
       );

  /// Label of the primary (save/create) pill.
  final String primaryLabel;

  /// Tap handler for the primary pill. Always wired; gate availability via
  /// [primaryEnabled] so the pill renders its disabled affordance instead
  /// of disappearing.
  final VoidCallback onPrimary;

  /// Leading glyph on the primary pill.
  final IconData primaryIcon;

  /// Disables the primary pill (e.g. while saving or with no changes).
  final bool primaryEnabled;

  /// Optional secondary (cancel) pill.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional destructive (delete) action. Renders as an icon-only round
  /// glass button in the row layout and as a labeled pill when stacked.
  final String? destructiveLabel;
  final VoidCallback? onDestructive;
  final bool destructiveEnabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= _stackPillsTextScale;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.only(
          top: spacing.step4,
          bottom: spacing.step4 + safeBottomInset,
        ),
        child: SettingsContentArea(
          child: stacked ? _buildStacked(tokens) : _buildRow(tokens),
        ),
      ),
    );
  }

  Widget _buildRow(DsTokens tokens) {
    final spacing = tokens.spacing;
    return Row(
      children: [
        if (onDestructive != null)
          DsGlassRoundButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: destructiveLabel!,
            iconColor: destructiveEnabled
                ? tokens.colors.alert.error.defaultColor
                : tokens.colors.text.lowEmphasis,
            onPressed: destructiveEnabled ? onDestructive! : () {},
          ),
        const Spacer(),
        if (onSecondary != null) ...[
          Flexible(child: _secondaryPill(tokens)),
          SizedBox(width: spacing.step3),
        ],
        Flexible(child: _primaryPill(tokens)),
      ],
    );
  }

  /// Stacked variant for large accessibility text: full-width pills, the
  /// primary action last (closest to the thumb), destructive first so it
  /// stays farthest from the default reach.
  Widget _buildStacked(DsTokens tokens) {
    final spacing = tokens.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onDestructive != null) ...[
          DsGlassPill(
            icon: Icons.delete_outline_rounded,
            label: destructiveLabel!,
            foregroundColor: tokens.colors.alert.error.defaultColor,
            enabled: destructiveEnabled,
            onTap: onDestructive!,
          ),
          SizedBox(height: spacing.step3),
        ],
        if (onSecondary != null) ...[
          _secondaryPill(tokens),
          SizedBox(height: spacing.step3),
        ],
        _primaryPill(tokens),
      ],
    );
  }

  Widget _secondaryPill(DsTokens tokens) => DsGlassPill(
    label: secondaryLabel!,
    fillColor: tokens.colors.surface.focusPressed,
    onTap: onSecondary!,
  );

  Widget _primaryPill(DsTokens tokens) => DsGlassPill(
    icon: primaryIcon,
    label: primaryLabel,
    fillColor: tokens.colors.interactive.enabled,
    foregroundColor: tokens.colors.text.onInteractiveAlert,
    enabled: primaryEnabled,
    onTap: onPrimary,
  );
}
