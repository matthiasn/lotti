import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The card pull requests sit in — on a task's page and under the
/// companion's reply — so both read as one thing: [children] top to
/// bottom, a header over the rows.
class PullRequestsCard extends StatelessWidget {
  const PullRequestsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// [rows] inside a [PullRequestsCard], inset so each row's rounded hover
/// fill floats inside the card's edge instead of running square into it,
/// with a hairline between rows.
class PullRequestRowList extends StatelessWidget {
  const PullRequestRowList({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step2,
        right: tokens.spacing.step2,
        bottom: tokens.spacing.step2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            // The linked-tasks card's separator, spanning the width a row's
            // hover fill does; held a step off the rows so a fill's rounded
            // corners never butt against it.
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
                child: const DesignSystemDivider(),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}
