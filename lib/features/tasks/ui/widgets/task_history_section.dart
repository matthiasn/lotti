import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The collapsible shell around the task's dated log-entry history (the
/// linked-entries stream plus reverse links).
///
/// Collapsed by default: the history is the page's longest region and a
/// reader landing on a task needs the summary, the todos and the linked
/// tasks before the full log. The header row — title plus rotating chevron —
/// stays pinned in the same spot in both states; only the content below it
/// comes and goes.
///
/// Expansion state is owned by the page, which force-expands the section
/// when a focus intent targets an entry inside it (a collapsed section has
/// no mounted entry keys to scroll to).
class TaskHistorySection extends StatelessWidget {
  const TaskHistorySection({
    required this.expanded,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// The history content — filter bar and entry stream. Kept out of the tree
  /// entirely while collapsed so a long log costs nothing until asked for.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          // ONE semantic control: the whole row is the button and the
          // chevron is a plain, non-interactive glyph inside it. A nested
          // IconButton exposed a duplicate control to assistive technology
          // for the same toggle.
          child: Semantics(
            expanded: expanded,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              onTap: onToggle,
              child: ConstrainedBox(
                // The chevron's IconButton used to supply the 48pt target;
                // the bare row keeps that floor itself.
                constraints: const BoxConstraints(
                  minHeight: TapTargets.minimum,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step2,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: tokens.spacing.step2),
                      Expanded(
                        child: Text(
                          context.messages.taskHistoryTitle,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          size: 24,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}
