import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';

/// Whether the picker assigns a single category or edits a set of categories.
enum CategoryPickerMode { single, multi }

/// Namespaced sentinel that represents the "Unassigned" pseudo-category in
/// multi mode. Stripped at the [showCategoryMultiPicker] boundary so it never
/// leaks to callers or collides with a real category id.
const String kCategoryPickerUnassignedSentinel =
    '__category_picker_unassigned__';

/// Sentinel id for the single-mode "clear" row (maps to [CategoryCleared]).
const String _kCategoryPickerClearSentinel = '__category_picker_clear__';

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
/// Selection is staged locally and only committed when the user taps Apply
/// (label overridable via [applyLabel]); dismissing discards the staged set and
/// resolves to `null`. On Apply the staged ids are returned via
/// [CategoryMultiResult]; the unassigned sentinel is stripped into the
/// `includesUnassigned` flag, and (when [intersectWithLiveIds] is true) ids no
/// longer present in [options] are dropped so callers never receive a dangling
/// id.
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
      stickyActionBarBuilder: (footerContext) => buildPickerApplyFooter(
        context: footerContext,
        label: applyLabel ?? footerContext.messages.doneButton,
        onTap: () => Navigator.of(footerContext).pop(staged.value),
        buttonKey: const ValueKey('category-picker-apply'),
      ),
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

/// The category adapter over [EntityPickerSheet].
///
/// One widget serves both modes:
/// * [CategoryPickerMode.single] — tap a row to apply and close; the currently
///   assigned category is pinned at the top, a "clear" row removes it.
/// * [CategoryPickerMode.multi] — rows toggle membership in [stagedNotifier];
///   the caller commits the staged set via the Apply footer.
///
/// Prefer the [showCategoryPicker] / [showCategoryMultiPicker] helpers over
/// constructing this directly; they wire up the modal and (multi) the staged
/// notifier lifecycle. Embedded callers (e.g. the embeddings backfill modal)
/// may construct it with an external [stagedNotifier] and
/// `reserveFooterInset: false`.
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
  final bool reserveFooterInset;

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  bool get _multi => widget.mode == CategoryPickerMode.multi;

  List<PickerEntry> _entries(String query) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();

    CategoryDefinition? current;
    if (!_multi && widget.currentCategoryId != null) {
      for (final c in filtered) {
        if (c.id == widget.currentCategoryId) {
          current = c;
          break;
        }
      }
    }

    final listed = (!_multi && current != null)
        ? filtered.where((c) => c.id != current!.id).toList()
        : filtered;
    final favorites = listed.where((c) => c.favorite ?? false).toList();
    final others = listed.where((c) => !(c.favorite ?? false)).toList();

    return [
      if (!_multi && current != null) _categoryItem(current),
      if (!_multi && widget.currentCategoryId != null) _clearItem(),
      if (_multi && widget.showUnassignedRow) _unassignedItem(),
      for (final c in favorites) _categoryItem(c),
      if (favorites.isNotEmpty && others.isNotEmpty) const PickerDivider(),
      for (final c in others) _categoryItem(c),
    ];
  }

  PickerItem _categoryItem(CategoryDefinition c) {
    final isPrivate = fromNullableBool(c.private);
    final isFavorite = c.favorite ?? false;
    return PickerItem(
      id: c.id,
      rowKey: ValueKey('category-picker-row-${c.id}'),
      leading: CategoryIconCompact(
        c.id,
        size: CategoryIconConstants.iconSizeMedium,
      ),
      title: c.name,
      // private/favorite are visual-only badges, so fold their state into the
      // row's accessible name.
      semanticLabel: [
        c.name,
        if (isPrivate) context.messages.categoryPrivateBadgeLabel,
        if (isFavorite) context.messages.categoryFavoriteBadgeLabel,
      ].join(', '),
      badges: [
        if (isPrivate)
          Icon(
            MdiIcons.security,
            color: context.colorScheme.error,
            size: CategoryIconConstants.iconSizeExtraSmall,
          ),
        if (isFavorite)
          // starredGold is the app-wide favorite indicator (shared across the
          // definitions lists); kept here deliberately rather than minted as a
          // one-off token. Pending an app-wide token-promotion pass.
          const Icon(
            MdiIcons.star,
            color: starredGold,
            size: CategoryIconConstants.iconSizeExtraSmall,
          ),
      ],
    );
  }

  PickerItem _clearItem() => PickerItem(
    id: _kCategoryPickerClearSentinel,
    rowKey: const ValueKey('category-picker-clear'),
    leading: Icon(
      Icons.block_rounded,
      color: context.designTokens.colors.text.mediumEmphasis,
      size: CategoryIconConstants.iconSizeMedium,
    ),
    title: context.messages.clearButton,
  );

  PickerItem _unassignedItem() => PickerItem(
    id: kCategoryPickerUnassignedSentinel,
    rowKey: const ValueKey('category-picker-unassigned'),
    leading: Icon(
      Icons.block_rounded,
      color: context.designTokens.colors.text.mediumEmphasis,
      size: CategoryIconConstants.iconSizeMedium,
    ),
    title: context.messages.tasksQuickFilterUnassignedLabel,
  );

  void _onPick(String id) {
    if (id == _kCategoryPickerClearSentinel) {
      Navigator.of(context).pop(const CategoryCleared());
      return;
    }
    final category =
        getIt<EntitiesCacheService>().getCategoryById(id) ??
        widget.options.where((c) => c.id == id).firstOrNull;
    if (category != null) {
      Navigator.of(context).pop(CategoryPicked(category));
    }
  }

  Future<String?> _createFromQuery(String query) async {
    CategoryDefinition? created;
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createCategoryTitle,
      builder: (_) => CategoryCreateModal(
        initialName: query,
        onCategoryCreated: (category) => created = category,
      ),
    );
    return created?.id;
  }

  bool _shouldShowCreate(String query) {
    if (!widget.allowCreate || query.isEmpty) {
      return false;
    }
    final q = query.toLowerCase();
    return !widget.options.any((c) => c.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return EntityPickerSheet(
      mode: _multi ? PickerMode.multi : PickerMode.single,
      entriesBuilder: _entries,
      searchHintText: context.messages.categorySearchPlaceholder,
      emptyMessage: context.messages.filterSelectionNoMatches,
      stagedNotifier: widget.stagedNotifier,
      selectedId: _multi ? null : widget.currentCategoryId,
      onPick: _multi ? null : _onPick,
      createFromQuery: widget.allowCreate ? _createFromQuery : null,
      shouldShowCreate: _shouldShowCreate,
      createRowKey: const ValueKey('category-picker-create'),
      reserveFooterInset: widget.reserveFooterInset,
    );
  }
}
