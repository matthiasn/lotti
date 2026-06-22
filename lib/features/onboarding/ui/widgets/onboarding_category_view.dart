import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

/// A selectable life-area option on the category step.
@immutable
class OnboardingCategoryOption {
  const OnboardingCategoryOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The "where should this brain work?" step: the user picks one or more life
/// areas (Work / Fitness / Family / Friends …) that the just-connected provider
/// should power. It teaches the app's core model — *which AI runs is chosen per
/// category* — instead of silently creating a throwaway "Test Category".
///
/// A natural-height panel (sits in the modal scroll view) over the shared alive
/// backdrop; the option chips arrive on a staggered cascade. Selection state +
/// callbacks are injected so it renders identically live and in review.
class OnboardingCategoryView extends StatelessWidget {
  const OnboardingCategoryView({
    required this.accent,
    required this.title,
    required this.explanation,
    required this.whyLabel,
    required this.continueLabel,
    required this.addOwnLabel,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onWhy,
    required this.onAddOwn,
    required this.onContinue,
    super.key,
  });

  final Color accent;

  /// "Where should your AI work?"
  final String title;

  /// Benefit-led lead copy (keeps each area separate). The per-category-AI
  /// mechanism lives behind [whyLabel] / [onWhy], not in the lead.
  final String explanation;

  /// Label for the "why areas?" disclosure.
  final String whyLabel;

  final String continueLabel;
  final String addOwnLabel;

  final List<OnboardingCategoryOption> options;

  /// Labels currently selected.
  final Set<String> selected;

  final void Function(String label) onToggle;
  final VoidCallback onWhy;
  final VoidCallback onAddOwn;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final panelBg = dsTokensDark.colors.background.level01;
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          // Calm, near-solid backing so the chip grid + secondary text read
          // cleanly — the alive backdrop stays a faint hint at the top edge
          // rather than bleeding sparkles behind small interactive targets.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0.45),
                    panelBg.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step6,
              tokens.spacing.step5,
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  explanation,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: textMedium,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onWhy,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacing.step2,
                      ),
                      child: Text(
                        whyLabel,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: accent,
                          decoration: TextDecoration.underline,
                          decorationColor: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                _CategoryGrid(
                  tokens: tokens,
                  accent: accent,
                  options: options,
                  selected: selected,
                  onToggle: onToggle,
                  addOwnLabel: addOwnLabel,
                  onAddOwn: onAddOwn,
                ),
                SizedBox(height: tokens.spacing.step7),
                DesignSystemButton(
                  label: continueLabel,
                  onPressed: selected.isEmpty ? null : onContinue,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tidy uniform grid of selectable area chips: the options laid out in rows
/// of two equal-width cells (`Expanded`), with the "+ Add your own" chip on its
/// own full-width row below. Every chip shares the same height + padding so the
/// grid never looks ragged (the review-panel blocker). An odd final option pairs
/// with an empty spacer so the column edges stay aligned.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.tokens,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.addOwnLabel,
    required this.onAddOwn,
  });

  final DsTokens tokens;
  final Color accent;
  final List<OnboardingCategoryOption> options;
  final Set<String> selected;
  final void Function(String label) onToggle;
  final String addOwnLabel;
  final VoidCallback onAddOwn;

  @override
  Widget build(BuildContext context) {
    final gap = tokens.spacing.step3;
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: gap));
      final left = options[i];
      final right = i + 1 < options.length ? options[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(
              child: _CategoryChip(
                tokens: tokens,
                accent: accent,
                option: left,
                selected: selected.contains(left.label),
                onTap: () => onToggle(left.label),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _CategoryChip(
                      tokens: tokens,
                      accent: accent,
                      option: right,
                      selected: selected.contains(right.label),
                      onTap: () => onToggle(right.label),
                    ),
            ),
          ],
        ),
      );
    }
    if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
    rows.add(
      _AddOwnChip(tokens: tokens, label: addOwnLabel, onTap: onAddOwn),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// One uniform area chip. Unselected reads as *available* — a neutral raised
/// surface with a bright border and full-white label, centred label only (no
/// per-category icon, which killed the mixed-metaphor icon set). Selected fills
/// solid brand and gains a leading check with a dark label.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.tokens,
    required this.accent,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final OnboardingCategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final fg = selected ? dsTokensDark.colors.background.level01 : textHigh;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionDurations.short4,
          curve: MotionCurves.standard,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step4,
          ),
          decoration: BoxDecoration(
            // Unselected reads as *available* (a neutral raised surface), not a
            // faint teal that looks disabled; selected fills solid brand.
            color: selected ? accent : textHigh.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: selected ? accent : textHigh.withValues(alpha: 0.62),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: tokens.spacing.step5,
                  color: fg,
                ),
                SizedBox(width: tokens.spacing.step2),
              ],
              Flexible(
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodyLarge.copyWith(
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-width "+ Add your own" chip. Shares the option chips' height +
/// padding so the grid stays uniform; rendered as an available neutral surface
/// (matching the unselected option chips) with a leading add glyph.
class _AddOwnChip extends StatelessWidget {
  const _AddOwnChip({
    required this.tokens,
    required this.label,
    required this.onTap,
  });

  final DsTokens tokens;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step4,
          ),
          // Secondary affordance, distinct from the selectable presets: no
          // fill, a dimmer border + label so it reads as "add" rather than a
          // peer option.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: textMedium.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: tokens.spacing.step5,
                color: textMedium,
              ),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodyLarge.copyWith(
                    color: textMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
