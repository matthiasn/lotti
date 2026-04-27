import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/settings_tree_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Crumb trail rendered in the Settings V2 page header.
///
/// Reads `settingsTreePathProvider` and resolves each id back to its
/// localized title via the [SettingsTreeScope] index. Renders one
/// segment per ancestor plus a synthetic "Settings" root segment, with
/// chevron separators in between. Non-terminal segments are tappable
/// and call `SettingsTreePath.truncateTo(depth)`, so users can drop
/// back up the tree from the title bar — the same behavior the old
/// in-pane crumbs used to provide before they were consolidated up
/// into the page header.
///
/// States:
/// - Empty path → only the localized root label is shown, rendered as
///   the highEmphasis terminal segment (no tap target — there is no
///   shorter path to truncate to).
/// - Non-empty path → root + every ancestor up to the focused node.
///   The trailing segment renders at highEmphasis as the page title;
///   every preceding segment is a tappable link.
///
/// Layout: a single horizontal line. The trailing (terminal) segment
/// is the only one that flexes — it ellipsizes when the available
/// width can't fit the full title (long localized labels, narrow
/// detail pane). The non-terminal segments stay at intrinsic width
/// because losing parts of the trail mid-string would make the
/// truncated tap targets ambiguous; the terminal segment carries a
/// [Tooltip] so the full title is still recoverable on hover. The
/// header itself stays at the spec'd fixed height — clipping is
/// avoided by ellipsis, not by growing the header.
///
/// The outer [Row] uses [MainAxisSize.max] because [Flexible] only
/// allocates remaining-width to its child when the parent flex has a
/// bounded main-axis extent (`MainAxisSize.min` short-circuits the
/// flex pass to intrinsic sizing, which would let the leaf overflow
/// instead of ellipsizing). Empty trailing space inside the row is
/// invisible and harmless — the surrounding header is responsible
/// for any future right-aligned content.
///
/// When no [SettingsTreeScope] is mounted (e.g. unit tests pumping the
/// header in isolation, or a deep link that briefly outruns the scope
/// host) the widget falls back to the localized root label only —
/// safer than rendering raw ids and doesn't require a brittle scope
/// fallback path.
class SettingsV2TopCrumbs extends ConsumerWidget {
  const SettingsV2TopCrumbs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final path = ref.watch(settingsTreePathProvider);
    final scope = SettingsTreeScope.maybeOf(context);
    final rootLabel = context.messages.settingsV2DetailRootCrumb;

    // Resolve each id to its node title. Ids that aren't in the
    // current (flag-gated) tree are silently dropped — the visible
    // trail just gets shorter rather than rendering a stale id.
    // When the scope isn't mounted at all, the loop produces no
    // titles and the trail collapses to just the root label.
    final ancestorTitles = <String>[];
    final index = scope?.index;
    if (index != null) {
      for (final id in path) {
        final title = index.findById(id)?.title;
        if (title != null) ancestorTitles.add(title);
      }
    }

    final segments = <String>[rootLabel, ...ancestorTitles];
    final headingStyle = tokens.typography.styles.heading.heading3;
    final highEmphasis = tokens.colors.text.highEmphasis;
    final mediumEmphasis = tokens.colors.text.mediumEmphasis;
    final lowEmphasis = tokens.colors.text.lowEmphasis;
    final accent = tokens.colors.interactive.enabled;

    void onTap(int depth) {
      ref.read(settingsTreePathProvider.notifier).truncateTo(depth);
    }

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
            child: Text(
              '›',
              style: headingStyle.copyWith(color: lowEmphasis),
            ),
          ),
        );
      }
      if (i < segments.length - 1) {
        children.add(
          _TopCrumbLink(
            label: segments[i],
            onTap: () => onTap(i),
            style: headingStyle.copyWith(color: mediumEmphasis),
            hoverColor: accent,
          ),
        );
      } else {
        children.add(
          Flexible(
            child: Tooltip(
              message: segments[i],
              child: Semantics(
                header: true,
                child: Text(
                  segments[i],
                  style: headingStyle.copyWith(color: highEmphasis),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Row(
      children: children,
    );
  }
}

/// Tappable header crumb segment. Mirrors the old `_CrumbLink` from
/// `leaf_panel.dart` (now removed): an [InkWell] surface that paints
/// its label in [hoverColor] while hovered or focused so the
/// affordance is visible without an underline decoration.
class _TopCrumbLink extends StatefulWidget {
  const _TopCrumbLink({
    required this.label,
    required this.onTap,
    required this.style,
    required this.hoverColor,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;
  final Color hoverColor;

  @override
  State<_TopCrumbLink> createState() => _TopCrumbLinkState();
}

class _TopCrumbLinkState extends State<_TopCrumbLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final active = _hovered || _focused;
    final style = active
        ? widget.style.copyWith(color: widget.hoverColor)
        : widget.style;
    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}
