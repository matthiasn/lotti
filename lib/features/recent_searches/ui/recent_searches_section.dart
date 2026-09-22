import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/domain/recent_search_list.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the sidebar's Recents section.
@visibleForTesting
abstract final class RecentSearchesSectionKeys {
  static const Key clear = Key('recent-searches-clear');
  static Key row(RecentSearch search) =>
      Key('recent-search-${search.surface.wireName}-${search.query}');
}

/// How one [RecentSearchSurface] is shown in the Recents section: the
/// destination's own glyph and name, so a row reads as "this search, there".
@immutable
class RecentSearchSurfacePresentation {
  const RecentSearchSurfacePresentation({
    required this.label,
    required this.icon,
  });

  /// The destination's navigation label — spoken, never drawn: the glyph
  /// carries the destination visually and the row's width goes to the query.
  final String label;

  /// The destination's own icon widget, as its navigation row builds it.
  /// Sized and coloured by the row through an [IconTheme], so it must not
  /// pin either itself.
  final Widget icon;
}

/// The Recents section of the mobile sidebar: searches run anywhere in the
/// app, newest first, each one tap away from being run again.
///
/// Lists only the searches whose surface appears in [surfaces]. The shell
/// passes the destinations enabled right now, so a search remembered on a
/// section that has since been switched off is not offered as a row with
/// nowhere to go — it stays stored and returns with its section.
///
/// The heading and its Clear control follow what is *stored*, not what is
/// listed. When every remembered search belongs to a switched-off section
/// there are no rows, but the history still exists, and the user must be
/// able to delete it without first turning that section back on. Only when
/// nothing is stored at all does the section render nothing, heading
/// included.
class RecentSearchesSection extends ConsumerWidget {
  const RecentSearchesSection({
    required this.surfaces,
    required this.onSelected,
    super.key,
  });

  final Map<RecentSearchSurface, RecentSearchSurfacePresentation> surfaces;

  /// Called with the tapped search. Navigating to its destination and
  /// applying the query is the host's job; this section only lists.
  final ValueChanged<RecentSearch> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(recentSearchesControllerProvider);
    if (stored.isEmpty) return const SizedBox.shrink();
    final searches = recentSearchesOn(stored, surfaces.keys.toSet());

    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // The heading starts on the rows' text inset, so it reads as their
          // title rather than as a row of its own.
          padding: EdgeInsetsDirectional.only(start: tokens.spacing.step5),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    messages.navSidebarRecentsTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ),
              ),
              DesignSystemButton(
                key: RecentSearchesSectionKeys.clear,
                label: messages.navSidebarRecentsClear,
                semanticsLabel: messages.navSidebarRecentsClearSemantics,
                variant: DesignSystemButtonVariant.quiet,
                size: DesignSystemButtonSize.dense,
                tapTargetSize: MaterialTapTargetSize.padded,
                onPressed: () => unawaited(
                  ref.read(recentSearchesControllerProvider.notifier).clear(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        for (final search in searches)
          _RecentSearchRow(
            key: RecentSearchesSectionKeys.row(search),
            search: search,
            presentation: surfaces[search.surface]!,
            onTap: () => onSelected(search),
          ),
      ],
    );
  }
}

/// One Recents row, on the sidebar's own row metrics — the same insets,
/// radius and icon column as a destination — so the section reads as part of
/// the rail and every row is a full touch target.
class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({
    required this.search,
    required this.presentation,
    required this.onTap,
    super.key,
  });

  final RecentSearch search;
  final RecentSearchSurfacePresentation presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);

    return Semantics(
      button: true,
      label: context.messages.navSidebarRecentSearchSemantics(
        presentation.label,
        search.query,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step3,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: tokens.spacing.step7,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconTheme(
                          data: IconThemeData(
                            size: IconSizes.m,
                            color: tokens.colors.text.lowEmphasis,
                          ),
                          child: presentation.icon,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        search.query,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(color: tokens.colors.text.mediumEmphasis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
