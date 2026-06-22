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
    required this.continueLabel,
    required this.addOwnLabel,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onAddOwn,
    required this.onContinue,
    super.key,
  });

  final Color accent;

  /// "Where should your AI work?"
  final String title;

  /// Plain-language: a different AI can run per area of life.
  final String explanation;

  final String continueLabel;
  final String addOwnLabel;

  final List<OnboardingCategoryOption> options;

  /// Labels currently selected.
  final Set<String> selected;

  final void Function(String label) onToggle;
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
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0),
                    panelBg.withValues(alpha: 0.55),
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
                SizedBox(height: tokens.spacing.step6),
                Wrap(
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step3,
                  children: [
                    for (final option in options)
                      _CategoryChip(
                        tokens: tokens,
                        accent: accent,
                        option: option,
                        selected: selected.contains(option.label),
                        onTap: () => onToggle(option.label),
                      ),
                    _AddOwnChip(
                      tokens: tokens,
                      label: addOwnLabel,
                      onTap: onAddOwn,
                    ),
                  ],
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
            vertical: tokens.spacing.step3,
          ),
          decoration: BoxDecoration(
            // Unselected reads as *available* (a neutral raised surface), not a
            // faint teal that looks disabled; selected fills solid brand.
            color: selected ? accent : textHigh.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: selected ? accent : textHigh.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : option.icon,
                size: tokens.spacing.step5,
                color: fg,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                option.label,
                style: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            vertical: tokens.spacing.step3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: textMedium.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: tokens.spacing.step5,
                color: textMedium,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                label,
                style: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
