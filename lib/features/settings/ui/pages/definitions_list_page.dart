import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// Size of the icon centered in list empty/error states. Matches the
/// pre-existing empty-state treatment on the categories and labels pages.
const double _stateIconSize = 64;

/// Unified list shell for the settings definition pages (categories,
/// labels, habits, measurables, dashboards).
///
/// One silhouette for every list: [SettingsPageHeader], a
/// [DesignSystemSearch] filter, rows inside a [DesignSystemGroupedList]
/// card, tokenized empty/no-match/error states, and a floating create
/// button. All content rides the shared settings grid
/// ([SettingsContentSliver]) so it aligns with the header title at every
/// pane width.
class DefinitionsListPage<T> extends StatefulWidget {
  const DefinitionsListPage({
    required this.title,
    required this.itemsAsync,
    required this.searchHint,
    required this.displayName,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyHint,
    required this.noMatchMessage,
    required this.errorTitle,
    required this.createLabel,
    required this.onCreate,
    this.searchText,
    this.noMatchActionBuilder,
    this.initialSearchTerm,
    this.searchCallback,
    super.key,
  });

  /// Header title.
  final String title;

  /// The definitions to render. Pages watch their Riverpod provider and
  /// hand the [AsyncValue] through so loading/error handling stays here.
  final AsyncValue<List<T>> itemsAsync;

  /// Placeholder for the search field.
  final String searchHint;

  /// Display name of an item — used as the sort key and the default
  /// search haystack.
  final String Function(T item) displayName;

  /// Row builder. `showDivider` is false for the last row of the card.
  final Widget Function(
    BuildContext context,
    T item, {
    required bool showDivider,
  })
  itemBuilder;

  /// Empty-state visuals when no definitions exist at all.
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyHint;

  /// Message when a search query matches nothing, e.g.
  /// `(q) => messages.settingsLabelsNoMatchQuery(q)`.
  final String Function(String query) noMatchMessage;

  /// Optional call-to-action under the no-match message (the labels page
  /// offers "create this label").
  final Widget Function(BuildContext context, String query)?
  noMatchActionBuilder;

  /// Title of the error state; the error itself renders underneath.
  final String errorTitle;

  /// Semantic label + handler for the floating create button.
  final String createLabel;
  final VoidCallback onCreate;

  /// Optional override for the search haystack (e.g. labels also match
  /// on description). Defaults to [displayName].
  final String Function(T item)? searchText;

  /// Seeds the search field (deep links like `/settings/habits/search/x`).
  final String? initialSearchTerm;

  /// Notifies hosts about query edits so URL-backed search routes stay in
  /// sync.
  final ValueChanged<String>? searchCallback;

  @override
  State<DefinitionsListPage<T>> createState() => _DefinitionsListPageState<T>();
}

class _DefinitionsListPageState<T> extends State<DefinitionsListPage<T>> {
  late String _queryRaw = widget.initialSearchTerm ?? '';

  String get _queryLower => _queryRaw.trim().toLowerCase();

  void _onQueryChanged(String value) {
    setState(() => _queryRaw = value);
    widget.searchCallback?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    // Desktop: creation lives in the header on the content axis (a FAB
    // pinned to the corner of a wide window strands it ~1000px from the
    // list it acts on). Mobile keeps the thumb-reachable FAB.
    final desktop = isDesktopLayout(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SettingsPageHeader(
            title: widget.title,
            showBackButton: !desktop,
            actions: desktop
                ? [
                    DesignSystemButton(
                      label: widget.createLabel,
                      leadingIcon: Icons.add,
                      onPressed: widget.onCreate,
                    ),
                  ]
                : null,
          ),
          ...widget.itemsAsync.when(
            data: (items) => _buildContentSlivers(context, items),
            loading: () => const [
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              SliverFillRemaining(
                child: _ListStateMessage(
                  icon: Icons.error_outline,
                  iconColor:
                      context.designTokens.colors.alert.error.defaultColor,
                  title: widget.errorTitle,
                  body: error.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: desktop
          ? null
          : DesignSystemBottomNavigationFabPadding(
              child: DesignSystemFloatingActionButton(
                semanticLabel: widget.createLabel,
                onPressed: widget.onCreate,
              ),
            ),
    );
  }

  List<Widget> _buildContentSlivers(BuildContext context, List<T> items) {
    final tokens = context.designTokens;
    final haystack = widget.searchText ?? widget.displayName;
    final filtered = items
        .where(
          (item) =>
              _queryLower.isEmpty ||
              haystack(item).toLowerCase().contains(_queryLower),
        )
        .sortedBy((item) => widget.displayName(item).toLowerCase())
        .toList();

    return [
      SettingsContentSliver(
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
            child: DesignSystemSearch(
              hintText: widget.searchHint,
              initialText: widget.initialSearchTerm,
              // DS search fires `onChanged('')` from its clear button, so
              // one callback covers typing and clearing.
              onChanged: _onQueryChanged,
            ),
          ),
        ),
      ),
      if (filtered.isEmpty)
        _buildEmptySliver(context, noItemsAtAll: items.isEmpty)
      else
        SettingsContentSliver(
          sliver: SliverToBoxAdapter(
            child: DesignSystemGroupedList(
              padding: EdgeInsets.zero,
              children: [
                for (final (index, item) in filtered.indexed)
                  widget.itemBuilder(
                    context,
                    item,
                    showDivider: index < filtered.length - 1,
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildEmptySliver(BuildContext context, {required bool noItemsAtAll}) {
    final query = _queryRaw.trim();
    if (!noItemsAtAll && query.isNotEmpty) {
      return SliverFillRemaining(
        child: _ListStateMessage(
          icon: Icons.search_off_rounded,
          title: widget.noMatchMessage(query),
          action: widget.noMatchActionBuilder?.call(context, query),
        ),
      );
    }
    return SliverFillRemaining(
      child: _ListStateMessage(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        body: widget.emptyHint,
        // Close the loop right where the instruction sits, instead of
        // pointing the reader at a create button in the opposite corner.
        action: DesignSystemButton(
          label: widget.createLabel,
          leadingIcon: Icons.add,
          onPressed: widget.onCreate,
        ),
      ),
    );
  }
}

/// Centered icon + title + optional body/action used by the empty,
/// no-match, and error states.
class _ListStateMessage extends StatelessWidget {
  const _ListStateMessage({
    required this.icon,
    required this.title,
    this.iconColor,
    this.body,
    this.action,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: _stateIconSize,
              color: iconColor ?? tokens.colors.text.lowEmphasis,
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                body!,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: tokens.spacing.step4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
