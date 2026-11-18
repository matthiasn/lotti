import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_choice_chip.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:material_ui/material_ui.dart';

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
/// On the shared [OnboardingStage]: her bubble says [title] and
/// [explanation], the tray holds the chips, [whyLabel] is the link above the
/// main button. Selection state + callbacks are injected so it renders
/// identically live and in review.
class OnboardingCategoryView extends StatelessWidget {
  const OnboardingCategoryView({
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
    this.caption,
    this.companion,
    this.progress,
    this.onClose,
    super.key,
  });

  /// The companion, on the stage above a speech bubble that says [title] and
  /// [explanation]; null shows them as a plain header.
  final Widget? companion;

  /// Where this step is in onboarding.
  final OnboardingProgress? progress;

  /// Leaves onboarding from here: there is no step to go back to once the
  /// key is connected.
  final VoidCallback? onClose;

  /// "Where should your AI work?"
  final String title;

  /// Benefit-led lead copy (keeps each area separate). The per-category-AI
  /// mechanism lives behind [whyLabel] / [onWhy], not in the lead.
  final String explanation;

  /// A short label over the chips. The host says there what Continue needs
  /// while nothing is picked, so a greyed button never explains itself.
  final String? caption;

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
    return OnboardingStage(
      companion: companion,
      title: title,
      text: explanation,
      progress: progress,
      // There is no step to go back to once the key is connected: the arrow
      // stays in its place in the bar, disabled.
      showBack: true,
      onClose: onClose,
      showClose: true,
      caption: caption,
      secondary: OnboardingStageAction(label: whyLabel, onPressed: onWhy),
      primary: OnboardingStageAction(
        label: continueLabel,
        onPressed: selected.isEmpty ? null : onContinue,
        icon: LottiIcons.forward,
      ),
      child: _CategoryGrid(
        tokens: tokens,
        options: options,
        selected: selected,
        onToggle: onToggle,
        addOwnLabel: addOwnLabel,
        onAddOwn: onAddOwn,
      ),
    );
  }
}

/// A responsive grid of area chips, with "+ Add your own" across a row of
/// its own under them, edge to edge with the grid. At the standard text scale and comfortable widths it uses
/// two equal columns; scaled text or narrow panels collapse to one column so
/// labels remain complete instead of ellipsizing.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.tokens,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.addOwnLabel,
    required this.onAddOwn,
  });

  final DsTokens tokens;
  final List<OnboardingCategoryOption> options;
  final Set<String> selected;
  final void Function(String label) onToggle;
  final String addOwnLabel;
  final VoidCallback onAddOwn;

  @override
  Widget build(BuildContext context) {
    final gap = tokens.spacing.step3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textIsScaled = MediaQuery.textScalerOf(context).scale(1) > 1;
        final panelIsNarrow = constraints.maxWidth < tokens.spacing.step13 * 2;
        final singleColumn = textIsScaled || panelIsNarrow;
        final cells = <Widget>[
          for (final option in options)
            OnboardingChoiceChip(
              label: option.label,
              icon: option.icon,
              selected: selected.contains(option.label),
              wrapLabel: singleColumn,
              onTap: () => onToggle(option.label),
            ),
        ];
        final columns = singleColumn ? 1 : 2;
        final rows = <Widget>[
          for (var i = 0; i < cells.length; i += columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      child: i + c < cells.length
                          ? cells[i + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...rows,
            SizedBox(height: gap),
            OnboardingChoiceChip(
              label: addOwnLabel,
              icon: LottiIcons.add,
              wrapLabel: true,
              onTap: onAddOwn,
            ),
          ],
        );
      },
    );
  }
}
