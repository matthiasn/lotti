import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One section of the form that edits something an agent serves — a goal, a
/// person: a heading, an optional line saying what the section is for, then
/// its fields, open on the page rather than boxed in a card of their own.
///
/// The goal form set the grammar — *Here's what I can watch* over its
/// signals, *Your agent* over the agent's name and category — and the person
/// form follows it section for section, so the two editors read as one
/// product: the same heading tier, the same quiet intro, the same space
/// between a heading and its first field. Sections are stacked with
/// `spacing.sectionGap` by the host.
class AgentFormSection extends StatelessWidget {
  const AgentFormSection({
    required this.title,
    required this.child,
    this.intro,
    this.introKey,
    super.key,
  });

  final String title;

  /// What the section is for, or a promise it keeps — one quiet line under
  /// the heading. Null for a section whose fields say it themselves.
  final String? intro;

  /// Identity for the intro line, for a section whose promise a test or a
  /// screen reader needs to find on its own.
  final Key? introKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        if (intro case final intro?) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            intro,
            key: introKey,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step5),
        child,
      ],
    );
  }
}
