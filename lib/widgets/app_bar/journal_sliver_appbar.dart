import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/widgets/ai_chat_icon.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';

class JournalSliverAppBar extends ConsumerStatefulWidget {
  const JournalSliverAppBar({
    this.searchFocusNode,
    super.key,
  });

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<JournalSliverAppBar> createState() =>
      _JournalSliverAppBarState();
}

class _JournalSliverAppBarState extends ConsumerState<JournalSliverAppBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    final showVectorToggle = state.enableVectorSearch;

    return SliverAppBar(
      pinned: true,
      // Match the page's card-on-canvas surface so the search/filter header
      // blends with the feed instead of reading as a black band.
      backgroundColor: dsPageSurface(context),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: showVectorToggle ? 140 : 100,
      title: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMedium,
                    horizontal: AppTheme.spacingSmall,
                  ),
                  child: DesignSystemSearch(
                    controller: _searchController,
                    focusNode: widget.searchFocusNode,
                    hintText: context.messages.searchHint,
                    onChanged: controller.setSearchString,
                    onClear: () => controller.setSearchString(''),
                  ),
                ),
              ),
              if (state.showTasks) ...[
                const AiChatIcon(),
                const TaskFilterIcon(),
              ] else
                const JournalFilterIcon(),
            ],
          ),
          if (showVectorToggle) _SearchModeRow(state: state),
        ],
      ),
    );
  }
}

class _SearchModeRow extends ConsumerWidget {
  const _SearchModeRow({required this.state});

  final JournalPageState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall,
          ),
          child: SegmentedButton<SearchMode>(
            selected: {state.searchMode},
            showSelectedIcon: false,
            onSelectionChanged: (selected) {
              controller.setSearchMode(selected.first);
            },
            segments: [
              ButtonSegment<SearchMode>(
                value: SearchMode.fullText,
                label: Text(
                  context.messages.searchModeFullText,
                  style: context.textTheme.bodySmall,
                ),
                icon: const Icon(Icons.text_fields, size: 16),
              ),
              ButtonSegment<SearchMode>(
                value: SearchMode.vector,
                label: Text(
                  context.messages.searchModeVector,
                  style: context.textTheme.bodySmall,
                ),
                icon: const Icon(Icons.hub_outlined, size: 16),
              ),
            ],
          ),
        ),
        if (state.vectorSearchInFlight)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (state.searchMode == SearchMode.vector &&
            state.vectorSearchElapsed != null)
          Text(
            context.messages.vectorSearchTiming(
              state.vectorSearchElapsed!.inMilliseconds,
              state.vectorSearchResultCount,
            ),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// The starred / flagged / private display toggles for the logbook filter.
///
/// These are three independent booleans (any combination can be on), so they
/// render as multi-select design-system choice pills — matching the entry-type
/// and tasks filters — rather than a single-select segmented control.
class JournalFilter extends ConsumerWidget {
  const JournalFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    final tokens = context.designTokens;
    Widget pill({
      required DisplayFilter filter,
      required IconData icon,
      required String label,
    }) {
      final active = state.filters.contains(filter);
      return DesignSystemFilterChoicePill(
        label: label,
        selected: active,
        role: DesignSystemFilterChoiceRole.multiSelect,
        leading: Icon(
          icon,
          size: tokens.spacing.step5,
          color: active
              ? tokens.colors.interactive.enabled
              : tokens.colors.text.mediumEmphasis,
        ),
        onTap: () {
          final next = {...state.filters};
          if (active) {
            next.remove(filter);
          } else {
            next.add(filter);
          }
          controller.setFilters(next);
        },
      );
    }

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        pill(
          filter: DisplayFilter.starredEntriesOnly,
          icon: Icons.star_rounded,
          label: context.messages.journalFilterStarred,
        ),
        pill(
          filter: DisplayFilter.flaggedEntriesOnly,
          icon: Icons.flag_rounded,
          label: context.messages.journalFilterFlagged,
        ),
        pill(
          filter: DisplayFilter.privateEntriesOnly,
          icon: Icons.shield_rounded,
          label: context.messages.journalFilterPrivate,
        ),
      ],
    );
  }
}

/// The full logbook filter, as shown in the filter modal: labeled sections for
/// the display toggles, entry types, and categories. Mirrors the sectioned
/// structure of the tasks filter sheet so the two filters read as one system.
class LogbookFilterSheet extends StatelessWidget {
  const LogbookFilterSheet({required this.onCategoryPressed, super.key});

  final VoidCallback onCategoryPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterSection(
          label: context.messages.journalFilterShowTitle,
          child: const JournalFilter(),
        ),
        SizedBox(height: tokens.spacing.step5),
        _FilterSection(
          label: context.messages.journalFilterEntryTypesTitle,
          child: const EntryTypeFilter(),
        ),
        SizedBox(height: tokens.spacing.step5),
        TaskCategoryFilterOverviewRow(onPressed: onCategoryPressed),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
    );
  }
}

class JournalFilterIcon extends ConsumerWidget {
  const JournalFilterIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    // Get the parent container to share with the modal
    final container = ProviderScope.containerOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: IconButton(
        tooltip: context.messages.journalFilterTitle,
        onPressed: () {
          final pageIndex = ValueNotifier(0);
          ModalUtils.showMultiPageModal<void>(
            context: context,
            pageIndexNotifier: pageIndex,
            modalDecorator: (child) {
              // Use UncontrolledProviderScope to share the parent container
              // with overrides for the modal-specific scope value
              return UncontrolledProviderScope(
                container: container,
                child: ProviderScope(
                  overrides: [
                    journalPageScopeProvider.overrideWithValue(showTasks),
                  ],
                  child: _JournalFilterBackHandler(
                    pageIndex: pageIndex,
                    child: child,
                  ),
                ),
              );
            },
            pageListBuilder: (modalContext) {
              final spacing = modalContext.designTokens.spacing;
              final padding = EdgeInsets.fromLTRB(
                spacing.step5,
                spacing.step2,
                spacing.step5,
                spacing.step5,
              );
              return [
                ModalUtils.modalSheetPage(
                  context: modalContext,
                  title: modalContext.messages.journalFilterTitle,
                  showCloseButton: true,
                  padding: padding,
                  child: LogbookFilterSheet(
                    onCategoryPressed: () => pageIndex.value = 1,
                  ),
                ),
                ModalUtils.modalSheetPage(
                  context: modalContext,
                  title: stripTrailingColon(
                    modalContext.messages.taskCategoryLabel,
                  ),
                  showCloseButton: true,
                  onTapBack: () => pageIndex.value = 0,
                  padding: padding,
                  stickyActionBar: _JournalCategoryActionBar(
                    onDone: () => pageIndex.value = 0,
                  ),
                  child: const TaskCategoryFilter(),
                ),
              ];
            },
          ).whenComplete(pageIndex.dispose);
        },
        icon: const Icon(MdiIcons.filterVariant),
      ),
    );
  }
}

class _JournalCategoryActionBar extends StatelessWidget {
  const _JournalCategoryActionBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(context.designTokens.spacing.step5),
      primary: DesignSystemButton(
        label: context.messages.doneButton,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}

class _JournalFilterBackHandler extends StatelessWidget {
  const _JournalFilterBackHandler({
    required this.pageIndex,
    required this.child,
  });

  final ValueNotifier<int> pageIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pageIndex,
      child: child,
      builder: (context, index, child) {
        final routeContent = PopScope<void>(
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && pageIndex.value != 0) {
              pageIndex.value = 0;
            }
          },
          child: child!,
        );
        if (index == 0) return routeContent;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              pageIndex.value = 0;
            },
          },
          child: Focus(autofocus: true, child: routeContent),
        );
      },
    );
  }
}
