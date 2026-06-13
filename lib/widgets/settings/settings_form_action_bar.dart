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

/// Alpha applied to the disabled primary pill's label (on top of the
/// pill's own fill dimming) so the disabled state changes on both axes —
/// background AND text — in both themes.
const double _disabledLabelAlpha = 0.45;

/// Sticky glass action bar shared by every settings definition detail page
/// (categories, labels, habits, measurables, dashboards).
///
/// Built on [DesignSystemGlassStrip] (hairline + backdrop blur + scrim), so
/// page content scrolls visibly behind it — hosts must mount it as
/// `Scaffold.bottomNavigationBar` with `extendBody: true` (handled by
/// `SettingsDetailScaffold`).
///
/// The bar carries the editing flow only: secondary/primary pills at the
/// end of the shared content column ([SettingsContentArea]) at intrinsic
/// width, plus optional [extraActions] at the start. Destructive actions
/// live in the form itself (`SettingsDeleteRow` via the scaffold) — three
/// labeled pills cannot fit a narrow phone in every locale, and Delete
/// does not belong next to Save anyway. At large accessibility text
/// scales the actions stack vertically, primary on top.
class SettingsFormActionBar extends StatelessWidget {
  const SettingsFormActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.extraActions,
    super.key,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'secondaryLabel and onSecondary must be provided together.',
       );

  /// Label of the primary (save/create) pill.
  final String primaryLabel;

  /// Tap handler for the primary pill. Always wired; gate availability via
  /// [primaryEnabled] so the pill renders its disabled affordance instead
  /// of disappearing.
  final VoidCallback onPrimary;

  /// Disables the primary pill (e.g. while saving or with no changes).
  final bool primaryEnabled;

  /// Optional secondary (cancel) pill.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional secondary entity actions (e.g. duplicate) rendered at the
  /// start of the bar. Typically [DsGlassRoundButton]s.
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
        ...?extraActions?.expand(
          (action) => [action, SizedBox(width: spacing.step3)],
        ),
        // Pills keep their intrinsic width; the Expanded inner row absorbs
        // the slack so labels never get squeezed into ellipses by flex
        // sharing.
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onSecondary != null) ...[
                Flexible(child: _secondaryPill(tokens)),
                SizedBox(width: spacing.step3),
              ],
              Flexible(child: _primaryPill(context, tokens)),
            ],
          ),
        ),
      ],
    );
  }

  /// Stacked variant for large accessibility text: full-width pills.
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
        // Primary first: when the horizontal [Cancel | Save] wraps into a
        // stack, the top slot keeps the primary action (skimming thumbs
        // land on Save, not on a destructive-by-omission Cancel).
        _primaryPill(context, tokens),
        if (onSecondary != null) ...[
          SizedBox(height: spacing.step3),
          _secondaryPill(tokens),
        ],
      ],
    );
  }

  /// Text-style escape hatch: no fill, no outline — Cancel must never
  /// out-shine the commit action in any theme. (A transparent fillColor
  /// takes DsGlassPill's solid path, which draws neither chip nor
  /// hairline.)
  Widget _secondaryPill(DsTokens tokens) => DsGlassPill(
    label: secondaryLabel!,
    fillColor: Colors.transparent,
    onTap: onSecondary!,
  );

  /// Primary pill. On pointer devices a tooltip surfaces the keyboard
  /// shortcut.
  Widget _primaryPill(BuildContext context, DsTokens tokens) {
    // The primary slot keeps the accent in BOTH states: vivid mint when
    // armed, the same mint dimmed to a tonal pill when disabled
    // (DsGlassPill applies the disabled fill factor and lowEmphasis
    // foreground). Recognizably the commit action either way — never a
    // bare label that the ghost Cancel could outrank.
    // No glyph in either state: the pill's footprint stays stable when
    // the form arms, and the accent fill alone carries the state. The
    // disabled label dims on the same on-accent color so the state pair
    // differs on both fill and text in light AND dark themes.
    final onAccent = tokens.colors.text.onInteractiveAlert;
    final pill = DsGlassPill(
      label: primaryLabel,
      fillColor: tokens.colors.interactive.enabled,
      foregroundColor: primaryEnabled
          ? onAccent
          : onAccent.withValues(alpha: onAccent.a * _disabledLabelAlpha),
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
