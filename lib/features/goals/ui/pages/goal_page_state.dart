import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What a goal page shows before it has a goal to show.
enum GoalPageStateKind {
  /// The first read is still on its way.
  loading,

  /// The read failed; a retry may bring the page.
  failed,

  /// The goal is gone — deleted here or on another device — or the address
  /// names something that is not a goal.
  notFound,
}

/// A goal page with nothing to show yet: the page's own way back over one
/// design-system state — the spinner on a first load, *This goal's page
/// didn't load* with *Try again*, or *This goal agent no longer exists*.
///
/// The goal detail, timeline and chat pages share it, so the three say the
/// same thing the same way. It replaces a raw Material app bar with an empty
/// title over a Material spinner or a bare line of text, which gave a failed
/// read no way forward and a deleted goal no explanation beyond one line.
class GoalPageState extends StatelessWidget {
  const GoalPageState({
    required this.kind,
    required this.onBack,
    this.onRetry,
    super.key,
  });

  final GoalPageStateKind kind;
  final VoidCallback onBack;

  /// Repeats the failed read; the *Try again* button shows only with it.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final retry = onRetry;
    final body = switch (kind) {
      GoalPageStateKind.loading => DesignSystemSpinner(
        semanticsLabel: messages.commonLoading,
      ),
      GoalPageStateKind.failed => DesignSystemEmptyState(
        key: const ValueKey('goal-page-load-failed'),
        icon: LottiIcons.warning,
        title: messages.goalPageLoadFailed,
        action: retry == null
            ? null
            : DesignSystemButton(
                key: const ValueKey('goal-page-retry'),
                label: messages.goalTryAgain,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: retry,
              ),
      ),
      GoalPageStateKind.notFound => DesignSystemEmptyState(
        key: const ValueKey('goal-page-not-found'),
        icon: LottiIcons.flag,
        title: messages.goalDetailNotFound,
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spacing.step3),
              child: DesignSystemIconAction(
                key: const ValueKey('goal-page-state-back'),
                icon: LottiIcons.chevronLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.step5),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
