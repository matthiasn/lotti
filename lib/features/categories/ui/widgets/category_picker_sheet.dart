import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Whether the picker assigns a single category or edits a set of categories.
enum CategoryPickerMode { single, multi }

/// Namespaced sentinel that represents the "Unassigned" pseudo-category in
/// multi mode. Stripped at the [showCategoryMultiPicker] boundary so it never
/// leaks to callers or collides with a real category id.
const String kCategoryPickerUnassignedSentinel =
    '__category_picker_unassigned__';

/// Result of a single-select category pick.
///
/// Three outcomes are distinguishable: a concrete [CategoryPicked], an explicit
/// [CategoryCleared] (the user chose "none"), and a dismiss (the `Future`
/// resolves to `null`). Use [CategorySingleResultX.categoryOrNull] when the
/// distinction between cleared and dismissed does not matter.
sealed class CategorySingleResult {
  const CategorySingleResult();
}

/// The user picked [category].
class CategoryPicked extends CategorySingleResult {
  const CategoryPicked(this.category);

  final CategoryDefinition category;
}

/// The user explicitly cleared the category assignment ("none").
class CategoryCleared extends CategorySingleResult {
  const CategoryCleared();
}

extension CategorySingleResultX on CategorySingleResult? {
  /// The picked category, or `null` for an explicit clear or a dismiss.
  CategoryDefinition? get categoryOrNull {
    final self = this;
    return self is CategoryPicked ? self.category : null;
  }

  /// Whether the user explicitly chose "none" (as opposed to dismissing).
  bool get isExplicitClear => this is CategoryCleared;
}

/// Result of a multi-select category edit. `changed` is `false` when the
/// committed set equals the seed, letting expensive callers skip a no-op
/// re-query.
typedef CategoryMultiResult = ({
  Set<String> ids,
  bool includesUnassigned,
  bool changed,
});

/// Opens the unified category picker in single mode.
///
/// Tapping a category applies it and closes immediately; the returned future
/// resolves to [CategoryPicked]. The "none" row resolves to [CategoryCleared];
/// dismissing resolves to `null`.
Future<CategorySingleResult?> showCategoryPicker({
  required BuildContext context,
  required String title,
  String? currentCategoryId,
  List<CategoryDefinition>? options,
  bool allowCreate = true,
}) {
  return ModalUtils.showSinglePageModal<CategorySingleResult>(
    context: context,
    title: title,
    builder: (modalContext) => CategoryPickerSheet(
      mode: CategoryPickerMode.single,
      options: options ?? getIt<EntitiesCacheService>().sortedCategories,
      currentCategoryId: currentCategoryId,
      allowCreate: allowCreate,
    ),
  );
}

/// Opens the unified category picker in multi mode.
///
/// Selection is staged locally and only committed when the user taps Apply;
/// dismissing discards the staged set and resolves to `null`. On Apply the
/// staged ids are returned via [CategoryMultiResult]; the unassigned sentinel
/// is stripped into the `includesUnassigned` flag, and (when
/// [intersectWithLiveIds] is true) ids no longer present in [options] are
/// dropped so callers never receive a dangling id.
Future<CategoryMultiResult?> showCategoryMultiPicker({
  required BuildContext context,
  required String title,
  required Set<String> initialSelectedIds,
  List<CategoryDefinition>? options,
  bool showUnassignedRow = false,
  bool allowCreate = true,
  bool intersectWithLiveIds = true,
  String? applyLabel,
}) async {
  final resolvedOptions =
      options ?? getIt<EntitiesCacheService>().sortedCategories;
  final staged = ValueNotifier<Set<String>>({...initialSelectedIds});
  try {
    final raw = await ModalUtils.showSinglePageModal<Set<String>>(
      context: context,
      title: title,
      stickyActionBarBuilder: (_) =>
          _CategoryPickerApplyFooter(staged: staged, label: applyLabel),
      builder: (modalContext) => CategoryPickerSheet(
        mode: CategoryPickerMode.multi,
        options: resolvedOptions,
        initialSelectedIds: initialSelectedIds,
        stagedNotifier: staged,
        showUnassignedRow: showUnassignedRow,
        allowCreate: allowCreate,
      ),
    );
    if (raw == null) {
      return null;
    }
    return resolveCategoryMultiResult(
      raw: raw,
      initialSelectedIds: initialSelectedIds,
      liveIds: resolvedOptions.map((c) => c.id).toSet(),
      intersectWithLiveIds: intersectWithLiveIds,
    );
  } finally {
    staged.dispose();
  }
}

/// Maps the raw staged set returned by the sheet into a [CategoryMultiResult].
///
/// Strips the unassigned sentinel into `includesUnassigned`, optionally drops
/// ids that are no longer live, and computes `changed` against the (sentinel-
/// normalized) seed. Pure so it can be unit/property tested without a modal.
@visibleForTesting
CategoryMultiResult resolveCategoryMultiResult({
  required Set<String> raw,
  required Set<String> initialSelectedIds,
  required Set<String> liveIds,
  required bool intersectWithLiveIds,
}) {
  final includesUnassigned = raw.contains(kCategoryPickerUnassignedSentinel);
  var ids = raw.where((id) => id != kCategoryPickerUnassignedSentinel).toSet();
  var seed = {...initialSelectedIds}..remove(kCategoryPickerUnassignedSentinel);
  // Normalize BOTH sides the same way so `changed` reflects a real edit and
  // not the intersect dropping a seed id that was already dead.
  if (intersectWithLiveIds) {
    ids = ids.intersection(liveIds);
    seed = seed.intersection(liveIds);
  }
  final seedUnassigned = initialSelectedIds.contains(
    kCategoryPickerUnassignedSentinel,
  );
  final changed = !setEquals(ids, seed) || includesUnassigned != seedUnassigned;
  return (ids: ids, includesUnassigned: includesUnassigned, changed: changed);
}

/// The unified category-selection sheet body.
///
/// One widget serves both modes:
/// * [CategoryPickerMode.single] — tap a row to apply and close; the currently
///   assigned category is pinned at the top, a "clear" row removes it.
/// * [CategoryPickerMode.multi] — rows toggle membership in [stagedNotifier];
///   the caller commits the staged set via the Apply footer.
///
/// Prefer the [showCategoryPicker] / [showCategoryMultiPicker] helpers over
/// constructing this directly; they wire up the modal and (multi) the staged
/// notifier lifecycle.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({
    required this.mode,
    required this.options,
    this.currentCategoryId,
    this.initialSelectedIds = const {},
    this.stagedNotifier,
    this.showUnassignedRow = false,
    this.allowCreate = true,
    this.reserveFooterInset = true,
    super.key,
  }) : assert(
         mode == CategoryPickerMode.single || stagedNotifier != null,
         'Multi mode requires a stagedNotifier.',
       );

  final CategoryPickerMode mode;

  /// Categories to show, already filtered by the caller (e.g. day-plan only).
  final List<CategoryDefinition> options;

  /// Single mode: the currently assigned category id (pinned + clearable).
  final String? currentCategoryId;

  /// Multi mode: the seed selection (used for the empty-staged display only;
  /// the live selection lives in [stagedNotifier]).
  final Set<String> initialSelectedIds;

  /// Multi mode: externally-owned staged selection. Toggling a row mutates it.
  final ValueNotifier<Set<String>>? stagedNotifier;

  /// Multi mode: whether to show the "Unassigned" pseudo-row.
  final bool showUnassignedRow;

  /// Whether a non-matching search query offers to create a new category.
  final bool allowCreate;

  /// Multi mode: whether to reserve bottom space for the glass Apply footer.
  /// The [showCategoryMultiPicker] helper renders that footer; embedded callers
  /// that supply their own action bar (e.g. the embeddings backfill modal)
  /// pass `false` so the list uses the full height.
  final bool reserveFooterInset;

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _multi => widget.mode == CategoryPickerMode.multi;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pick(CategoryDefinition category) {
    Navigator.of(context).pop(CategoryPicked(category));
  }

  void _clear() {
    Navigator.of(context).pop(const CategoryCleared());
  }

  void _toggle(String id) {
    final notifier = widget.stagedNotifier!;
    final next = {...notifier.value};
    if (!next.add(id)) {
      next.remove(id);
    }
    notifier.value = next;
  }

  Future<void> _openCreate(String name) async {
    CategoryDefinition? created;
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createCategoryTitle,
      builder: (_) => CategoryCreateModal(
        initialName: name,
        onCategoryCreated: (category) {
          created = category;
          if (_multi) {
            final notifier = widget.stagedNotifier!;
            notifier.value = {...notifier.value, category.id};
          }
        },
      ),
    );
    if (!mounted) {
      return;
    }
    final newCategory = created;
    if (newCategory == null) {
      return;
    }
    if (_multi) {
      // The new category is already staged; clear the search so the stale
      // "create" row for the same query cannot reappear (and re-create a dup).
      setState(() {
        _query = '';
        _searchController.clear();
      });
    } else {
      Navigator.of(context).pop(CategoryPicked(newCategory));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();

    CategoryDefinition? currentCategory;
    if (!_multi && widget.currentCategoryId != null) {
      for (final c in filtered) {
        if (c.id == widget.currentCategoryId) {
          currentCategory = c;
          break;
        }
      }
    }

    final listed = (!_multi && currentCategory != null)
        ? filtered.where((c) => c.id != currentCategory!.id).toList()
        : filtered;
    final favorites = listed.where((c) => c.favorite ?? false).toList();
    final others = listed.where((c) => !(c.favorite ?? false)).toList();

    final showCreateRow =
        widget.allowCreate && filtered.isEmpty && _query.trim().isNotEmpty;

    final hasMetaRow =
        (!_multi && widget.currentCategoryId != null) ||
        (_multi && widget.showUnassignedRow);
    final hasAnyRow =
        currentCategory != null ||
        hasMetaRow ||
        favorites.isNotEmpty ||
        others.isNotEmpty;
    final showEmptyState = !showCreateRow && !hasAnyRow;

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = math.min(screenHeight * 0.9, 640).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step5),
            child: DesignSystemSearch(
              controller: _searchController,
              hintText: context.messages.categorySearchPlaceholder,
              semanticsLabel: context.messages.categorySearchPlaceholder,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (value) {
                if (showCreateRow) {
                  _openCreate(value.trim());
                } else if (!_multi && filtered.length == 1) {
                  // Single mode: Enter applies the lone match, mirroring a tap.
                  _pick(filtered.first);
                }
              },
              onClear: () => setState(() => _query = ''),
            ),
          ),
          if (showCreateRow)
            Align(
              alignment: Alignment.topCenter,
              child: _CreateCategoryRow(
                query: _query.trim(),
                onTap: () => _openCreate(_query.trim()),
              ),
            )
          else if (showEmptyState)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.step6),
                  child: Text(
                    context.messages.filterSelectionNoMatches,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _multi
                  ? ValueListenableBuilder<Set<String>>(
                      valueListenable: widget.stagedNotifier!,
                      builder: (_, staged, _) => _buildList(
                        tokens: tokens,
                        favorites: favorites,
                        others: others,
                        currentCategory: currentCategory,
                        staged: staged,
                      ),
                    )
                  : _buildList(
                      tokens: tokens,
                      favorites: favorites,
                      others: others,
                      currentCategory: currentCategory,
                      staged: const {},
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildList({
    required DsTokens tokens,
    required List<CategoryDefinition> favorites,
    required List<CategoryDefinition> others,
    required CategoryDefinition? currentCategory,
    required Set<String> staged,
  }) {
    Widget categoryRow(CategoryDefinition c) => _PickerRow(
      rowKey: ValueKey('category-picker-row-${c.id}'),
      leading: CategoryIconCompact(
        c.id,
        size: CategoryIconConstants.iconSizeMedium,
      ),
      title: c.name,
      multi: _multi,
      selected: _multi
          ? staged.contains(c.id)
          : c.id == widget.currentCategoryId,
      badges: [
        if (fromNullableBool(c.private))
          Semantics(
            label: context.messages.categoryPrivateBadgeLabel,
            child: Icon(
              MdiIcons.security,
              color: context.colorScheme.error,
              size: CategoryIconConstants.iconSizeExtraSmall,
            ),
          ),
        if (c.favorite ?? false)
          Semantics(
            label: context.messages.categoryFavoriteBadgeLabel,
            // starredGold is the app-wide favorite indicator (shared across the
            // definitions lists); kept here deliberately rather than minted as a
            // one-off token. Pending an app-wide token-promotion pass.
            child: const Icon(
              MdiIcons.star,
              color: starredGold,
              size: CategoryIconConstants.iconSizeExtraSmall,
            ),
          ),
      ],
      onTap: () => _multi ? _toggle(c.id) : _pick(c),
    );

    return ListView(
      padding: EdgeInsets.only(
        bottom: (_multi && widget.reserveFooterInset)
            ? DesignSystemGlassActionFooter.reservedHeight
            : 0,
      ),
      children: [
        if (!_multi && currentCategory != null) categoryRow(currentCategory),
        if (!_multi && widget.currentCategoryId != null)
          _PickerRow(
            rowKey: const ValueKey('category-picker-clear'),
            leading: Icon(
              Icons.block_rounded,
              color: tokens.colors.text.mediumEmphasis,
              size: CategoryIconConstants.iconSizeMedium,
            ),
            title: context.messages.clearButton,
            multi: false,
            selected: false,
            onTap: _clear,
          ),
        if (_multi && widget.showUnassignedRow)
          _PickerRow(
            rowKey: const ValueKey('category-picker-unassigned'),
            leading: Icon(
              Icons.block_rounded,
              color: tokens.colors.text.mediumEmphasis,
              size: CategoryIconConstants.iconSizeMedium,
            ),
            title: context.messages.tasksQuickFilterUnassignedLabel,
            multi: true,
            selected: staged.contains(kCategoryPickerUnassignedSentinel),
            onTap: () => _toggle(kCategoryPickerUnassignedSentinel),
          ),
        for (final c in favorites) categoryRow(c),
        if (favorites.isNotEmpty && others.isNotEmpty)
          Divider(
            height: tokens.spacing.step6,
            color: tokens.colors.decorative.level01,
          ),
        for (final c in others) categoryRow(c),
      ],
    );
  }
}

/// A single tappable row shared by category rows and the meta rows
/// (clear / unassigned). In multi mode the trailing affordance is a
/// [DesignSystemCheckbox]; in single mode a selected row shows a check.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.leading,
    required this.title,
    required this.multi,
    required this.selected,
    required this.onTap,
    this.badges = const [],
    this.rowKey,
  });

  final Widget leading;
  final String title;
  final bool multi;
  final bool selected;
  final VoidCallback onTap;
  final List<Widget> badges;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    final trailing = multi
        ? ExcludeSemantics(
            child: DesignSystemCheckbox(
              value: selected,
              semanticsLabel: title,
              onChanged: (_) {
                onTap();
              },
            ),
          )
        : selected
        ? Icon(Icons.check_rounded, color: tokens.colors.interactive.enabled)
        : null;

    return MergeSemantics(
      child: Semantics(
        selected: multi ? null : selected,
        checked: multi ? selected : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: rowKey,
            borderRadius: BorderRadius.circular(tokens.radii.l),
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? tokens.colors.surface.selected
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radii.l),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.step1,
                  vertical: spacing.step4,
                ),
                child: Row(
                  children: [
                    leading,
                    SizedBox(width: spacing.step4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                    ),
                    for (final badge in badges) ...[
                      SizedBox(width: spacing.step2),
                      badge,
                    ],
                    if (trailing != null) ...[
                      SizedBox(width: spacing.step3),
                      trailing,
                    ],
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

/// The "create category from search" row, shown when the query matches no
/// existing category. Visually distinct from a category row: a plain add glyph
/// instead of a colored identity chip, and no selection affordance.
class _CreateCategoryRow extends StatelessWidget {
  const _CreateCategoryRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '${context.messages.createCategoryTitle}: $query',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('category-picker-create'),
            borderRadius: BorderRadius.circular(tokens.radii.l),
            onTap: onTap,
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.step1,
                  vertical: spacing.step4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: tokens.colors.text.mediumEmphasis,
                      size: CategoryIconConstants.iconSizeMedium,
                    ),
                    SizedBox(width: spacing.step4),
                    Expanded(
                      child: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(
                              color: tokens.colors.text.mediumEmphasis,
                            ),
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

/// Sticky Apply footer for multi mode. Pops the modal with the staged set.
class _CategoryPickerApplyFooter extends StatelessWidget {
  const _CategoryPickerApplyFooter({required this.staged, this.label});

  final ValueNotifier<Set<String>> staged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    return DesignSystemGlassActionFooter(
      child: DesignSystemFilterActionButton(
        key: const ValueKey('category-picker-apply'),
        label: label ?? context.messages.doneButton,
        palette: palette,
        highlighted: true,
        textStyle: tokens.typography.styles.subtitle.subtitle1,
        onTap: () => Navigator.of(context).pop(staged.value),
      ),
    );
  }
}
