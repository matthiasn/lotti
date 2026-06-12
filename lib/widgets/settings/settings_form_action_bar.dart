import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    this.extraActions,
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

  /// Optional destructive (delete) action, rendered as a labeled quiet
  /// pill with the error color carrying the meaning.
  final String? destructiveLabel;
  final VoidCallback? onDestructive;
  final bool destructiveEnabled;

  /// Optional secondary entity actions (e.g. duplicate) rendered next to
  /// the destructive pill, so every action on an editor lives on one bar.
  /// Typically [DsGlassRoundButton]s.
  final List<Widget>? extraActions;

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
          child: stacked
              ? _buildStacked(context, tokens)
              : _buildRow(context, tokens),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, DsTokens tokens) {
    final spacing = tokens.spacing;
    return Row(
      children: [
        if (onDestructive != null) Flexible(child: _destructivePill(tokens)),
        ...?extraActions?.expand(
          (action) => [SizedBox(width: spacing.step3), action],
        ),
        const Spacer(),
        if (onSecondary != null) ...[
          Flexible(child: _secondaryPill(tokens)),
          SizedBox(width: spacing.step3),
        ],
        Flexible(child: _primaryPill(context, tokens)),
      ],
    );
  }

  /// Stacked variant for large accessibility text: full-width pills, the
  /// primary action last (closest to the thumb), destructive first so it
  /// stays farthest from the default reach.
  Widget _buildStacked(BuildContext context, DsTokens tokens) {
    final spacing = tokens.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (extraActions != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [...?extraActions],
          ),
          SizedBox(height: spacing.step3),
        ],
        if (onDestructive != null) ...[
          _destructivePill(tokens),
          SizedBox(height: spacing.step3),
        ],
        if (onSecondary != null) ...[
          _secondaryPill(tokens),
          SizedBox(height: spacing.step3),
        ],
        _primaryPill(context, tokens),
      ],
    );
  }

  /// Labeled destructive pill: a solid quiet surface (theme-correct on
  /// light and dark glass) with the error color carrying the meaning.
  /// Always labeled — an icon-only destructive control is invisible to
  /// users who scan for words.
  Widget _destructivePill(DsTokens tokens) => DsGlassPill(
    icon: Icons.delete_outline_rounded,
    label: destructiveLabel!,
    fillColor: tokens.colors.background.level02,
    foregroundColor: tokens.colors.alert.error.defaultColor,
    enabled: destructiveEnabled,
    onTap: onDestructive!,
  );

  Widget _secondaryPill(DsTokens tokens) => DsGlassPill(
    label: secondaryLabel!,
    fillColor: tokens.colors.surface.focusPressed,
    onTap: onSecondary!,
  );

  /// Primary pill. Disabled drops the solid interactive fill entirely for
  /// the quiet translucent glass treatment, so available-vs-unavailable is
  /// legible at a glance instead of two similar shades of the accent. On
  /// pointer devices a tooltip surfaces the keyboard shortcut.
  Widget _primaryPill(BuildContext context, DsTokens tokens) {
    final pill = DsGlassPill(
      icon: primaryIcon,
      label: primaryLabel,
      fillColor: primaryEnabled ? tokens.colors.interactive.enabled : null,
      foregroundColor: primaryEnabled
          ? tokens.colors.text.onInteractiveAlert
          : null,
      enabled: primaryEnabled,
      onTap: onPrimary,
    );
    if (!isDesktopLayout(context) || !primaryEnabled) return pill;
    return Tooltip(
      message: context.messages.saveShortcutTooltip,
      child: pill,
    );
  }
}
