import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_filter_modal.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_search_mode_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';

/// The infinitely-scrolling journal feed (the non-tasks list, `showTasks ==
/// false`).
///
/// Drives [journalPageControllerProvider] and overrides
/// [journalPageScopeProvider] to `false` for the subtree, so descendant
/// widgets (header, filter modal) resolve the journal-scoped controller
/// without threading the flag manually. The body renders the shared
/// [TabSectionHeader] (title, search, filter affordance — the same header
/// Tasks and Projects use), the vector-search mode row when enabled, and the
/// paged feed via `infinite_scroll_pagination`, rendering each page item
/// through [CardWrapperWidget] (optionally with a vector-search distance
/// badge). Pull-to-refresh calls `refreshQuery`.
typedef InfiniteJournalCreateEntryCallback =
    Future<JournalEntity?> Function({String? categoryId});

class InfiniteJournalPage extends ConsumerWidget {
  const InfiniteJournalPage({
    this.onCreateEntry = createTextEntry,
    super.key,
  });

  final InfiniteJournalCreateEntryCallback onCreateEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPageControllerProvider(false));
    final selectedCategoryIds = state.selectedCategoryIds;
    final categoryId = selectedCategoryIds.length == 1
        ? selectedCategoryIds.first
        : null;

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(false),
      ],
      child: AppCommandScope(
        debugLabel: 'journal-list',
        handlers: {
          AppCommandId.refresh: AppCommandHandler(
            invoke: (_) => ref
                .read(journalPageControllerProvider(false).notifier)
                .refreshQuery(preserveVisibleItems: true),
          ),
          AppCommandId.createInContext: AppCommandHandler(
            invoke: (_) => onCreateEntry(categoryId: categoryId),
          ),
        },
        child: Scaffold(
          // Adopt the shared "card-on-canvas" surface (as on Tasks, Habits and
          // Time Analysis): a calm page canvas a step darker than the cards,
          // instead of the near-black default scaffold.
          backgroundColor: dsPageSurface(context),
          // During the first-run zero-state the inline "Create new entry" CTA
          // is the single primary action — a second, identical affordance
          // floating in the corner would just compete with it.
          floatingActionButton: state.pagingController == null
              ? FloatingAddActionButton(categoryId: categoryId)
              : ValueListenableBuilder<PagingState<int, JournalEntity>>(
                  valueListenable: state.pagingController!,
                  builder: (context, paging, _) {
                    final loadedEmpty =
                        paging.pages != null &&
                        (paging.items?.isEmpty ?? false) &&
                        !paging.isLoading;
                    final firstRun = loadedEmpty && !_feedNarrowedByUser(state);
                    return firstRun
                        ? const SizedBox.shrink()
                        : FloatingAddActionButton(categoryId: categoryId);
                  },
                ),
          body: const _InfiniteJournalPageBody(),
        ),
      ),
    );
  }
}

/// Localized zero-state for the logbook feed, replacing the pagination
/// package's stock indicator so the empty screen speaks the design system's
/// grammar.
///
/// Two causes render differently: a feed narrowed by the user's search or
/// filters explains how to recover, while a genuinely empty logbook is a
/// first-run launchpad with an inline create action (the same
/// [CreateEntryModal] path as the FAB, which sits far from where the user is
/// looking).
class _LogbookEmptyState extends StatelessWidget {
  const _LogbookEmptyState({
    required this.narrowedByUserInput,
  });

  /// True when a search string or any user filter narrows the feed — the
  /// emptiness is then a query result, not an empty logbook.
  final bool narrowedByUserInput;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return DesignSystemEmptyState(
      icon: Icons.menu_book_outlined,
      title: narrowedByUserInput
          ? messages.logbookNoMatchesTitle
          : messages.logbookEmptyTitle,
      hint: narrowedByUserInput
          ? messages.logbookNoMatchesHint
          : messages.logbookEmptyHint,
      // The CTA only renders on a genuinely empty logbook, which by definition
      // has no category filter applied — so there is no category to preselect
      // here (unlike the FAB, which can inherit a single active category).
      action: narrowedByUserInput
          ? null
          : DesignSystemButton(
              label: messages.createEntryLabel,
              leadingIcon: Icons.add_rounded,
              onPressed: () => CreateEntryModal.show(
                context: context,
                linkedFromId: null,
                categoryId: null,
              ),
            ),
    );
  }
}

/// True when the user's search string or any user-controlled filter narrows
/// the feed — emptiness is then a query result, not an empty logbook.
bool _feedNarrowedByUser(JournalPageState state) {
  return state.match.isNotEmpty ||
      state.filters.isNotEmpty ||
      state.selectedCategoryIds.isNotEmpty ||
      _entryTypesNarrowedByUser(state);
}

/// True when the user has deselected any entry type that active feature flags
/// currently allow. Compares the selection against the live
/// [JournalPageState.allowedEntryTypes] baseline rather than a static set, so
/// deselecting an enabled gated type (e.g. events) counts as narrowing, while a
/// type hidden by a feature flag — which is never in the baseline — does not.
bool _entryTypesNarrowedByUser(JournalPageState state) {
  final allowed = state.allowedEntryTypes;
  if (allowed.isEmpty) {
    return false;
  }
  final selected = state.selectedEntryTypes.toSet();
  return allowed.any((type) => !selected.contains(type));
}

class _InfiniteJournalPageBody extends ConsumerStatefulWidget {
  const _InfiniteJournalPageBody();

  @override
  ConsumerState<_InfiniteJournalPageBody> createState() =>
      _InfiniteJournalPageBodyState();
}

class _InfiniteJournalPageBodyState
    extends ConsumerState<_InfiniteJournalPageBody> {
  final _scrollController = ScrollController();
  final _searchFocusNode = FocusNode(debugLabel: 'journal-search');

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();

    // Trigger initial fetch when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(journalPageControllerProvider(false).notifier).refreshQuery();
      }
    });
  }

  @override
  void dispose() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController
      ..removeListener(listener)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalPageControllerProvider(false));
    final controller = ref.read(
      journalPageControllerProvider(false).notifier,
    );
    final tokens = context.designTokens;

    return AppCommandScope(
      debugLabel: 'journal-search',
      handlers: {
        AppCommandId.focusSearch: AppCommandHandler(
          invoke: (_) => _searchFocusNode.requestFocus(),
        ),
      },
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // The same titled header Tasks and Projects use, so the three
            // list panes read as one system.
            TabSectionHeader(
              searchFocusNode: _searchFocusNode,
              title: context.messages.navTabTitleJournal,
              query: state.match,
              searchHint: context.messages.searchHint,
              filterTooltip: context.messages.journalFilterTitle,
              // An invisibly filtered infinite list reads as "everything";
              // the affordance flips to its active treatment whenever any
              // filter narrows the feed.
              filtersActive:
                  state.filters.isNotEmpty ||
                  state.selectedCategoryIds.isNotEmpty ||
                  _entryTypesNarrowedByUser(state),
              onSearchChanged: (value) {
                unawaited(controller.setSearchString(value));
              },
              onSearchCleared: () {
                unawaited(controller.setSearchString(''));
              },
              onSearchPressed: (value) {
                unawaited(controller.setSearchString(value));
              },
              onFilterPressed: () => showLogbookFilterModal(context),
            ),
            if (state.enableVectorSearch)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                child: DetailContentWidth(
                  child: LogbookSearchModeRow(state: state),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshQuery,
                child: CustomScrollView(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: <Widget>[
                    if (state.pagingController != null)
                      PagingListener<int, JournalEntity>(
                        controller: state.pagingController!,
                        builder: (context, pagingState, fetchNextPageFunction) {
                          return PagedSliverList<int, JournalEntity>(
                            state: pagingState,
                            fetchNextPage: fetchNextPageFunction,
                            builderDelegate:
                                PagedChildBuilderDelegate<JournalEntity>(
                                  animateTransitions: true,
                                  invisibleItemsThreshold: 10,
                                  // The package's stock "No items found"
                                  // indicator is another design system's UI
                                  // and reads as a failed query; replace it
                                  // with the localized logbook zero-state.
                                  noItemsFoundIndicatorBuilder: (context) =>
                                      _LogbookEmptyState(
                                        narrowedByUserInput:
                                            _feedNarrowedByUser(state),
                                      ),
                                  itemBuilder: (context, item, index) {
                                    final distance = state.showDistances
                                        ? state.vectorSearchDistances[item
                                              .meta
                                              .id]
                                        : null;
                                    return CardWrapperWidget(
                                      item: item,
                                      vectorDistance: distance,
                                      key: ValueKey(item.meta.id),
                                    );
                                  },
                                ),
                          );
                        },
                      )
                    else
                      const SliverToBoxAdapter(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    // Ensure the final card can scroll above overlays
                    // (FAB/time indicator).
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: tokens.spacing.step11 + tokens.spacing.step6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
