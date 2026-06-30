import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Stable keys for the mobile saved-filter rail.
@visibleForTesting
class SavedTaskFilterRailKeys {
  const SavedTaskFilterRailKeys._();

  static const Key root = Key('saved-filter-rail');
  static const Key savedButton = Key('saved-filter-rail-saved-button');
  static const Key allPill = Key('saved-filter-rail-all-pill');
  static const Key customPill = Key('saved-filter-rail-custom-pill');
  static const Key saveChip = Key('saved-filter-rail-save-chip');
  static Key pill(String id) => Key('saved-filter-rail-pill-$id');
}

/// The always-on glance band above the task list. Rendered only when ≥1 saved
/// filter exists; otherwise it collapses to nothing so the layout is unchanged
/// for users without saved filters.
///
/// Left → right: a chip-chromed "Saved" button with a disclosure chevron
/// (opens the complete sheet — it carries no filter-count badge so it never
/// reads like a third task-count next to the pill numbers), then a hard-capped,
/// non-scrolling run of pills — "All" (clears to the default view), the active
/// saved pill (or a "Custom" pill carrying the live filtered count for an
/// ad-hoc filter), and as many most-recently-used quick-jump pills as fit — and
/// a trailing teal "+ Save" call-to-action pill shown only when the live filter
/// has unsaved clauses. Overflow lives in the sheet; the rail never scrolls.
///
/// At large text (textScaler ≥ ~1.3) the rail collapses to the "Saved" button +
/// a compact "All" reset + the single active anchor pill (dropping the MRU
/// pills). "All" is kept even in the collapse because clearing back to the
/// unfiltered view is the most common escape hatch — dropping it would regress
/// return-to-unfiltered from one tap to two.
class SavedTaskFilterRail extends ConsumerWidget {
  const SavedTaskFilterRail({super.key});

  /// Hard cap on MRU quick-jump pills regardless of available width.
  static const int maxMruPills = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final saved =
        ref.watch(savedTaskFiltersControllerProvider).value ??
        const <SavedTaskFilter>[];
    if (saved.isEmpty) {
      return const SizedBox.shrink(key: SavedTaskFilterRailKeys.root);
    }

    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final hasUnsaved = ref.watch(tasksFilterHasUnsavedClausesProvider);
    // Stale-while-revalidate: keep the last-known counts during a refresh so
    // pills never flash back to `–` on a background sync.
    final counts = ref.watch(savedTaskFilterCountsProvider).value;
    final total = ref.watch(allTasksTotalCountProvider).value;
    final mruOrder = ref.watch(savedTaskFilterMruProvider);

    final activeFilter = activeId == null
        ? null
        : saved.where((f) => f.id == activeId).firstOrNull;
    final allSelected = activeId == null && !hasUnsaved;

    // The "Custom" anchor's live magnitude. Only watched when an ad-hoc filter
    // is active (`hasUnsaved` implies no saved filter matched, hence no active
    // saved pill), so the count query never runs for the common saved/"All"
    // views. Stale-while-revalidate via `AsyncValue.value` keeps the last count
    // during a background recompute instead of flashing back to `–`.
    final customCount = hasUnsaved
        ? ref.watch(currentTasksFilterCountProvider).value
        : null;
    final customCountLoading = hasUnsaved && customCount == null;

    final mruCandidates = _orderedMru(
      saved: saved,
      mruOrder: mruOrder,
      excludeId: activeFilter?.id,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: Semantics(
        container: true,
        label: messages.tasksSavedFiltersGroupSemantics,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = SizedBox(width: tokens.spacing.step2);
            final savedButton = _SavedButton(
              onTap: () => showSavedTaskFiltersSheet(context),
            );
            final saveChip = _SaveChip(
              onTap: () => promptSaveCurrentTaskFilter(context, ref),
            );

            // Large text (textScaler ≥ ~1.3): collapse to the active anchor +
            // a compact "All" reset + the "Saved" button (only the MRU
            // quick-jumps are dropped). The active anchor LEADS so the user's
            // current filter + count is the first thing on-screen and always
            // fully readable; "All" (the reset) and "Saved" follow. The run is
            // horizontally scrollable so at accessibility text sizes the
            // trailing chips scroll into view instead of overflowing — which is
            // acceptable here precisely because the collapse is ~3 chips, not
            // the many-filter scrub-to-find case the rail's no-scroll rule
            // guards against. "All" is kept because return-to-unfiltered is the
            // most common escape hatch; when "All" *is* the active selection it
            // doubles as the anchor rather than being rendered twice.
            final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
            if (largeText) {
              final Widget anchor;
              final bool allIsAnchor;
              if (activeFilter != null) {
                allIsAnchor = false;
                anchor = _savedPill(
                  context,
                  ref,
                  filter: activeFilter,
                  selected: true,
                  count: counts?[activeFilter.id],
                  countLoading: counts == null,
                );
              } else if (hasUnsaved) {
                allIsAnchor = false;
                anchor = _customPill(
                  context,
                  count: customCount,
                  countLoading: customCountLoading,
                );
              } else {
                allIsAnchor = true;
                anchor = _allPill(context, ref, selected: true, total: total);
              }
              return SingleChildScrollView(
                key: SavedTaskFilterRailKeys.root,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cap the leading anchor at the viewport width: a long name
                    // ellipsizes (the name stays `Flexible` inside DsPill, the
                    // count is never clipped) instead of pushing the row
                    // arbitrarily wide, while a short name stays content-sized.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: anchor,
                    ),
                    if (!allIsAnchor) ...[
                      gap,
                      _allPill(context, ref, selected: false, total: total),
                    ],
                    gap,
                    savedButton,
                    if (hasUnsaved) ...[gap, saveChip],
                  ],
                ),
              );
            }

            final hasAnchorPill = activeFilter != null || hasUnsaved;
            final maxMru = _fitMruCount(
              tokens: tokens,
              available: constraints.maxWidth,
              hasAnchorPill: hasAnchorPill,
              showSaveChip: hasUnsaved,
            );
            final mru = mruCandidates.take(maxMru).toList(growable: false);

            return Row(
              key: SavedTaskFilterRailKeys.root,
              children: [
                savedButton,
                gap,
                _allPill(context, ref, selected: allSelected, total: total),
                if (activeFilter != null) ...[
                  gap,
                  Flexible(
                    child: _savedPill(
                      context,
                      ref,
                      filter: activeFilter,
                      selected: true,
                      count: counts?[activeFilter.id],
                      countLoading: counts == null,
                    ),
                  ),
                ] else if (hasUnsaved) ...[
                  gap,
                  Flexible(
                    child: _customPill(
                      context,
                      count: customCount,
                      countLoading: customCountLoading,
                    ),
                  ),
                ],
                for (final f in mru) ...[
                  gap,
                  _savedPill(
                    context,
                    ref,
                    filter: f,
                    selected: false,
                    count: counts?[f.id],
                    countLoading: counts == null,
                  ),
                ],
                if (hasUnsaved) ...[gap, saveChip],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The neutral "All" pill (clears to the default view). Non-flexible in the
  /// normal rail so it stays compact and the active pill gets priority width;
  /// the large-text collapse wraps it in a `Flexible` when it is the anchor.
  Widget _allPill(
    BuildContext context,
    WidgetRef ref, {
    required bool selected,
    required int? total,
  }) {
    final messages = context.messages;
    return SavedTaskFilterPill(
      key: SavedTaskFilterRailKeys.allPill,
      label: messages.tasksSavedFiltersAllShort,
      selected: selected,
      count: total,
      countLoading: total == null,
      semanticsLabel: _semanticsFor(
        context,
        name: messages.tasksSavedFiltersAllTasks,
        count: total,
      ),
      onTap: () => _applyAll(ref),
    );
  }

  /// The "Custom" anchor pill for an ad-hoc filter that matches no saved view;
  /// tapping it opens the sheet (paired with the chevron cue). It carries the
  /// live filtered task count in the same reserved tabular slot as every other
  /// pill (a `–` placeholder while the count is still computing) — the active
  /// filter must never hide its magnitude.
  Widget _customPill(
    BuildContext context, {
    required int? count,
    required bool countLoading,
  }) {
    final messages = context.messages;
    return SavedTaskFilterPill(
      key: SavedTaskFilterRailKeys.customPill,
      label: messages.tasksSavedFiltersCustom,
      selected: true,
      count: count,
      countLoading: countLoading,
      semanticsLabel: _semanticsFor(
        context,
        name: messages.tasksSavedFiltersCustom,
        count: countLoading ? null : count,
      ),
      onTap: () => showSavedTaskFiltersSheet(context),
      onOpenSheet: () => showSavedTaskFiltersSheet(context),
    );
  }

  Widget _savedPill(
    BuildContext context,
    WidgetRef ref, {
    required SavedTaskFilter filter,
    required bool selected,
    required int? count,
    required bool countLoading,
  }) {
    return SavedTaskFilterPill(
      key: SavedTaskFilterRailKeys.pill(filter.id),
      label: filter.name,
      selected: selected,
      categoryColor: savedFilterCategoryColor(filter),
      count: count,
      countLoading: countLoading,
      semanticsLabel: _semanticsFor(
        context,
        name: filter.name,
        category: savedFilterCategoryName(filter),
        count: countLoading ? null : count,
      ),
      onTap: selected
          ? () => showSavedTaskFiltersSheet(context)
          : () => _applySaved(ref, filter),
      onOpenSheet: selected ? () => showSavedTaskFiltersSheet(context) : null,
    );
  }

  Future<void> _applySaved(WidgetRef ref, SavedTaskFilter filter) async {
    await SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).activate(filter);
    ref.read(savedTaskFilterMruProvider.notifier).touch(filter.id);
  }

  Future<void> _applyAll(WidgetRef ref) {
    return SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).clearToDefault();
  }

  /// Builds the "{category}, {name}, {count} tasks" label, dropping the count
  /// clause entirely on cold start / dropped counts (never speaks `–`).
  String _semanticsFor(
    BuildContext context, {
    required String name,
    String? category,
    int? count,
  }) {
    final messages = context.messages;
    return [
      ?category,
      name,
      if (count != null) messages.tasksSavedFiltersTaskCount(count),
    ].join(', ');
  }

  /// Saved filters in MRU order (most recent first), then the remaining saved
  /// filters in stored order, excluding [excludeId]. The rail takes as many as
  /// fit from the front.
  List<SavedTaskFilter> _orderedMru({
    required List<SavedTaskFilter> saved,
    required List<String> mruOrder,
    required String? excludeId,
  }) {
    final byId = {for (final f in saved) f.id: f};
    final seen = <String>{};
    final ordered = <SavedTaskFilter>[];
    for (final id in mruOrder) {
      if (id == excludeId || seen.contains(id)) continue;
      final f = byId[id];
      if (f != null) {
        ordered.add(f);
        seen.add(id);
      }
    }
    for (final f in saved) {
      if (f.id == excludeId || seen.contains(f.id)) continue;
      ordered.add(f);
      seen.add(f.id);
    }
    return ordered;
  }

  /// Coarse, deterministic fit: how many MRU pills the remaining width holds
  /// after reserving the fixed head (Saved button + All pill + optional Save
  /// chip) and a generous slot for the flexible anchor pill. Hard-capped at
  /// [maxMruPills]. Widths are token-derived layout heuristics, so overflow is
  /// decided by layout — not implementer judgement — and the rail never scrolls.
  int _fitMruCount({
    required DsTokens tokens,
    required double available,
    required bool hasAnchorPill,
    required bool showSaveChip,
  }) {
    final gap = tokens.spacing.step2; // 4
    final savedButton = tokens.spacing.step12 + tokens.spacing.step3; // ~104
    final allPill = tokens.spacing.step11; // 80
    final saveChip = showSaveChip ? tokens.spacing.step11 : 0.0; // 80
    final anchorReserve = hasAnchorPill ? tokens.spacing.step13 : 0.0; // 160
    final mruPill = tokens.spacing.step12; // 96 per quick-jump pill

    final fixedHead = savedButton + gap + allPill + saveChip + anchorReserve;
    final remaining = available - fixedHead;
    if (remaining <= 0) return 0;
    final fits = (remaining / (mruPill + gap)).floor();
    return fits.clamp(0, maxMruPills);
  }
}

/// The band-leading "Saved" button. Wears the same neutral filled+bordered
/// [DsPill] chrome as the "All" pill (so it reads as a chip, not a static
/// label), led by a bookmark glyph and closed by a disclosure chevron that
/// signals "opens a menu". It deliberately carries **no** filter-count badge —
/// "Saved (5)" read like a third task-count beside "All 214" and the pill
/// numbers, conflating "5 saved definitions" with "N matching tasks". One tap
/// opens the complete sheet; the ≥48dp tap target comes from the padded
/// [InkWell] wrapper, never a mutated pill height.
class _SavedButton extends StatelessWidget {
  const _SavedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final label = messages.tasksSavedFiltersRailButton;
    // Primary on-surface for both the label (DsPill's filled default) and the
    // glyphs: at medium emphasis the bookmark + chevron read gray-on-gray over
    // the light-theme pill fill. High emphasis keeps the whole button legible.
    final glyphColor = tokens.colors.text.highEmphasis;

    final pill = DsPill(
      variant: DsPillVariant.filled,
      bordered: true,
      label: label,
      leading: Icon(
        Icons.bookmarks_outlined,
        size: tokens.spacing.step4,
        color: glyphColor,
      ),
      trailing: Icon(
        Icons.expand_more_rounded,
        size: tokens.spacing.step4,
        color: glyphColor,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: SavedTaskFilterRailKeys.savedButton,
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTarget),
              child: Center(widthFactor: 1, heightFactor: 1, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing "+ Save" call-to-action, shown only while the live filter has
/// unsaved clauses. A teal `outline` [DsPill] (NOT the muted dashed ghost-chip
/// skin, which is reserved for true empty/placeholder states) so it reads as a
/// live action, wrapped in a ≥48dp tap target.
class _SaveChip extends StatelessWidget {
  const _SaveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final accent = tokens.colors.interactive.enabled;
    final label = messages.tasksSavedFiltersSaveButtonLabel;

    final pill = DsPill(
      variant: DsPillVariant.outline,
      color: accent,
      label: label,
      leading: Icon(
        Icons.add_rounded,
        size: tokens.spacing.step4,
        color: accent,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: SavedTaskFilterRailKeys.saveChip,
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTarget),
              child: Center(widthFactor: 1, heightFactor: 1, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}
