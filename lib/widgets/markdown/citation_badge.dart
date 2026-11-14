import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The number of a source an answer cites: inline after the claim it
/// supports, and again before that source in the list beneath, so the two
/// read as one pair.
///
/// It replaces gpt_markdown's own chip for `[1]`, an unthemed circle whose
/// digit could not be read in either theme. With [onTap] it is a focusable
/// link to its source; without, it only names it.
class CitationBadge extends StatelessWidget {
  const CitationBadge(this.number, {this.onTap, super.key});

  /// The citation as written: `1` for `[1]`.
  final String number;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.aiCard.accentSoft,
        borderRadius: radius,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
        child: Text(
          number,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.aiCard.accent,
            // Every digit equally wide, so numbered rows line up.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    return Semantics(
      link: onTap != null,
      // The child's own tap action is excluded below; screen readers activate
      // the link through this one.
      onTap: onTap,
      label: context.messages.citationSource(number),
      excludeSemantics: true,
      child: onTap == null
          ? badge
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              mouseCursor: SystemMouseCursors.click,
              child: badge,
            ),
    );
  }
}
