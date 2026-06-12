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
    this.primaryIcon = Icons.check_rounded,
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

  /// Leading glyph on the primary pill.
  final IconData primaryIcon;

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

  /// Quiet ghost pill: the escape hatch must never out-shine the commit
  /// action, so Cancel gets the translucent glass treatment (hairline
  /// outline, no fill).
  Widget _secondaryPill(DsTokens tokens) => DsGlassPill(
    label: secondaryLabel!,
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
    final pill = DsGlassPill(
      icon: primaryIcon,
      label: primaryLabel,
      fillColor: tokens.colors.interactive.enabled,
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
