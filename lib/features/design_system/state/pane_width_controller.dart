import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

/// Settings keys for persisted pane widths.
const sidebarWidthKey = 'PANE_WIDTH_SIDEBAR';
const listPaneWidthKey = 'PANE_WIDTH_LIST';
const journalListPaneWidthKey = 'PANE_WIDTH_JOURNAL_LIST';
const sidebarCollapsedKey = 'PANE_WIDTH_SIDEBAR_COLLAPSED';
const listPaneCollapsedKey = 'PANE_WIDTH_LIST_COLLAPSED';
const dayViewPanelWidthKey = 'PANE_WIDTH_DAY_VIEW';
const dayViewPanelHiddenKey = 'PANE_WIDTH_DAY_VIEW_HIDDEN';

/// Default and constraint values for pane widths.
///
/// Sidebar and list-pane defaults are 20% narrower than their original
/// 320/540 flat values — on wide windows [scaledPaneWidth] scales both up
/// simultaneously, and at the original values the combined sidebar + list
/// pane consumed ~60% of a 1920px-wide window, leaving the detail pane
/// visibly cramped relative to the other two columns.
const defaultSidebarWidth = 256.0;
const minSidebarWidth = 200.0;
const maxSidebarWidth = 500.0;

const defaultListPaneWidth = 432.0;
const minListPaneWidth = 300.0;
const maxListPaneWidth = 800.0;

/// The logbook list pane resizes independently of the tasks/projects list
/// pane: logbook rows are denser and carry longer free-text previews, so the
/// width that reads well there is not the width that reads well for tasks.
const defaultJournalListPaneWidth = 460.0;
const minJournalListPaneWidth = 300.0;
const maxJournalListPaneWidth = 800.0;

/// The always-available day-view column docked on the right edge of the
/// desktop shell. Narrower than the list panes by default — it is a
/// glanceable companion, not a primary surface — but resizable up to the
/// same 800 ceiling so the planned/actual lanes can sit side by side.
const defaultDayViewPanelWidth = 380.0;
const minDayViewPanelWidth = 300.0;
const maxDayViewPanelWidth = 800.0;

/// How long to wait after the last drag update before persisting to disk.
@visibleForTesting
const persistDebounce = Duration(milliseconds: 300);

/// Reference window width the flat pane-width defaults above were tuned
/// for — a common laptop/desktop width. Below this, [scaledPaneWidth]
/// returns its input unchanged.
const kPaneWidthReferenceScreenWidth = 1440.0;

/// Scales [width] proportionally with [screenWidth] on windows wider than
/// [kPaneWidthReferenceScreenWidth], clamped to [minValue]/[maxValue].
///
/// Only applies when [width] still equals [flatDefault] — i.e. the sidebar
/// or list pane has never been persisted/dragged by the user — so a large
/// window gets a proportionally larger default instead of a fixed pane
/// leaving the remaining space (typically the detail pane) disproportionately
/// large, while any explicit user width is always honored verbatim. Callers
/// pass [width] = the controller's current (possibly still-loading) value
/// and [screenWidth] = `MediaQuery.sizeOf(context).width` from a widget that
/// has real layout constraints, since the controller itself has no
/// `BuildContext` to read them from.
double scaledPaneWidth({
  required double width,
  required double flatDefault,
  required double minValue,
  required double maxValue,
  required double screenWidth,
}) {
  if (width != flatDefault) return width;
  if (screenWidth <= kPaneWidthReferenceScreenWidth) return width;
  final scaled = flatDefault * screenWidth / kPaneWidthReferenceScreenWidth;
  return scaled.clamp(minValue, maxValue);
}

/// Bundles [scaledPaneWidth]'s displayed width with an `onDrag` handler ready
/// to hand a `ResizableDivider`.
///
/// The displayed width (screen-scaled) can differ from `storedWidth` (the
/// controller's raw persisted value), but `onDelta` — the controller's own
/// delta-relative update method, e.g. `updateSidebarWidth` /
/// `updateListPaneWidth` — always expects a delta relative to `storedWidth`.
/// A raw pointer delta would desync the divider from the pointer on the very
/// first drag frame after scaling, so `onDrag` adjusts it by
/// `(displayed + delta) - storedWidth` before forwarding to `onDelta`.
///
/// Shared by every desktop split-pane host (`beamer_app.dart`,
/// `dashboards_list_page.dart`, `projects_tab_page.dart`,
/// `tasks_root_page.dart`) so the scaling + delta-adjustment formula lives in
/// exactly one place.
typedef ResolvedPaneWidth = ({
  double width,
  void Function(double delta) onDrag,
});

ResolvedPaneWidth resolvedPaneWidth({
  required double storedWidth,
  required double flatDefault,
  required double minValue,
  required double maxValue,
  required double screenWidth,
  required void Function(double delta) onDelta,
}) {
  final width = scaledPaneWidth(
    width: storedWidth,
    flatDefault: flatDefault,
    minValue: minValue,
    maxValue: maxValue,
    screenWidth: screenWidth,
  );
  return (
    width: width,
    onDrag: (delta) => onDelta((width + delta) - storedWidth),
  );
}

/// State holding the current pane widths and the collapsed/hidden flags
/// shared by the desktop navigation sidebar, the Tasks/Projects list pane and
/// the docked day-view column.
///
/// [sidebarWidth] doubles as the restore target for
/// `PaneWidthController.expandSidebar`: while collapsed the controller
/// refuses drag input, so the field keeps the pre-collapse value untouched
/// and there is no need for a separate "lastExpandedSidebarWidth" slot.
@immutable
class PaneWidths {
  const PaneWidths({
    this.sidebarWidth = defaultSidebarWidth,
    this.listPaneWidth = defaultListPaneWidth,
    this.journalListPaneWidth = defaultJournalListPaneWidth,
    this.dayViewPanelWidth = defaultDayViewPanelWidth,
    this.sidebarCollapsed = false,
    this.listPaneCollapsed = false,
    this.dayViewPanelHidden = true,
  });

  final double sidebarWidth;
  final double listPaneWidth;
  final double journalListPaneWidth;
  final double dayViewPanelWidth;
  final bool sidebarCollapsed;
  final bool listPaneCollapsed;

  /// Whether the docked day-view column is hidden. Defaults to **hidden** —
  /// the column is opt-in, brought up from its rail when the user wants the
  /// day beside the tasks list, and the choice then persists. Like the
  /// collapse flags above, [dayViewPanelWidth] keeps the restore width while
  /// hidden because width drags are refused in that state.
  final bool dayViewPanelHidden;

  PaneWidths copyWith({
    double? sidebarWidth,
    double? listPaneWidth,
    double? journalListPaneWidth,
    double? dayViewPanelWidth,
    bool? sidebarCollapsed,
    bool? listPaneCollapsed,
    bool? dayViewPanelHidden,
  }) {
    return PaneWidths(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      listPaneWidth: listPaneWidth ?? this.listPaneWidth,
      journalListPaneWidth: journalListPaneWidth ?? this.journalListPaneWidth,
      dayViewPanelWidth: dayViewPanelWidth ?? this.dayViewPanelWidth,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      listPaneCollapsed: listPaneCollapsed ?? this.listPaneCollapsed,
      dayViewPanelHidden: dayViewPanelHidden ?? this.dayViewPanelHidden,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneWidths &&
          runtimeType == other.runtimeType &&
          sidebarWidth == other.sidebarWidth &&
          listPaneWidth == other.listPaneWidth &&
          journalListPaneWidth == other.journalListPaneWidth &&
          dayViewPanelWidth == other.dayViewPanelWidth &&
          sidebarCollapsed == other.sidebarCollapsed &&
          listPaneCollapsed == other.listPaneCollapsed &&
          dayViewPanelHidden == other.dayViewPanelHidden;

  @override
  int get hashCode => Object.hash(
    sidebarWidth,
    listPaneWidth,
    journalListPaneWidth,
    dayViewPanelWidth,
    sidebarCollapsed,
    listPaneCollapsed,
    dayViewPanelHidden,
  );
}

/// Keep-alive Riverpod notifier owning the resizable sidebar and list-pane
/// widths and their collapsed flags.
///
/// Loads persisted, clamped widths from `SettingsDb` on build, applies drag
/// deltas, and debounces writes back to disk. Once the user adjusts a width,
/// a late-arriving persisted load is ignored so it cannot clobber the live
/// value.
final paneWidthControllerProvider =
    NotifierProvider<PaneWidthController, PaneWidths>(
      PaneWidthController.new,
      name: 'paneWidthControllerProvider',
    );

class PaneWidthController extends Notifier<PaneWidths> {
  bool _userAdjusted = false;
  Timer? _sidebarDebounce;
  Timer? _listPaneDebounce;
  Timer? _journalListPaneDebounce;
  Timer? _dayViewPanelDebounce;

  @override
  PaneWidths build() {
    ref.onDispose(() {
      _sidebarDebounce?.cancel();
      _listPaneDebounce?.cancel();
      _journalListPaneDebounce?.cancel();
      _dayViewPanelDebounce?.cancel();
    });
    unawaited(_loadPersistedWidths());
    return const PaneWidths();
  }

  Future<void> _loadPersistedWidths() async {
    try {
      final settingsDb = getIt<SettingsDb>();
      final values = await settingsDb.itemsByKeys({
        sidebarWidthKey,
        listPaneWidthKey,
        journalListPaneWidthKey,
        dayViewPanelWidthKey,
        sidebarCollapsedKey,
        listPaneCollapsedKey,
        dayViewPanelHiddenKey,
      });

      if (_userAdjusted) return;

      final sidebarWidth = _parseWidth(
        values[sidebarWidthKey],
        defaultSidebarWidth,
        minSidebarWidth,
        maxSidebarWidth,
      );
      final listPaneWidth = _parseWidth(
        values[listPaneWidthKey],
        defaultListPaneWidth,
        minListPaneWidth,
        maxListPaneWidth,
      );
      final journalListPaneWidth = _parseWidth(
        values[journalListPaneWidthKey],
        defaultJournalListPaneWidth,
        minJournalListPaneWidth,
        maxJournalListPaneWidth,
      );
      final dayViewPanelWidth = _parseWidth(
        values[dayViewPanelWidthKey],
        defaultDayViewPanelWidth,
        minDayViewPanelWidth,
        maxDayViewPanelWidth,
      );
      final sidebarCollapsed = values[sidebarCollapsedKey] == 'true';
      final listPaneCollapsed = values[listPaneCollapsedKey] == 'true';
      // Hidden unless the user has explicitly shown the column: a missing
      // key (never toggled) keeps the hidden default.
      final dayViewPanelHidden = values[dayViewPanelHiddenKey] != 'false';

      state = PaneWidths(
        sidebarWidth: sidebarWidth,
        listPaneWidth: listPaneWidth,
        journalListPaneWidth: journalListPaneWidth,
        dayViewPanelWidth: dayViewPanelWidth,
        sidebarCollapsed: sidebarCollapsed,
        listPaneCollapsed: listPaneCollapsed,
        dayViewPanelHidden: dayViewPanelHidden,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'PANE_WIDTH loadPersistedWidths failed: $error\n$stackTrace',
      );
    }
  }

  double _parseWidth(
    String? stored,
    double defaultValue,
    double minValue,
    double maxValue,
  ) {
    if (stored == null) return defaultValue;
    final parsed = double.tryParse(stored);
    if (parsed == null || !parsed.isFinite) return defaultValue;
    return parsed.clamp(minValue, maxValue);
  }

  /// Applies a drag [delta] to the sidebar width, clamped to
  /// [minSidebarWidth]..[maxSidebarWidth], and debounces persistence. Ignored
  /// while the sidebar is collapsed.
  void updateSidebarWidth(double delta) {
    // Ignore drag deltas while collapsed — dragging is disabled in that mode
    // to prevent intermediate widths that would clip labels, and collapse
    // relies on `sidebarWidth` staying put as the restore target for expand.
    if (state.sidebarCollapsed) return;
    _userAdjusted = true;
    final newWidth = (state.sidebarWidth + delta).clamp(
      minSidebarWidth,
      maxSidebarWidth,
    );
    state = state.copyWith(sidebarWidth: newWidth);
    _debounceSidebarPersist();
  }

  /// Applies a drag [delta] to the list-pane width, clamped to
  /// [minListPaneWidth]..[maxListPaneWidth], and debounces persistence.
  ///
  /// A hidden pane keeps its restore width frozen. A host that deliberately
  /// forces the list and divider visible despite a latent collapsed preference
  /// may set [allowWhileCollapsed] so that visible resize affordance remains
  /// operational.
  void updateListPaneWidth(
    double delta, {
    bool allowWhileCollapsed = false,
  }) {
    if (state.listPaneCollapsed && !allowWhileCollapsed) return;
    _userAdjusted = true;
    final newWidth = (state.listPaneWidth + delta).clamp(
      minListPaneWidth,
      maxListPaneWidth,
    );
    state = state.copyWith(listPaneWidth: newWidth);
    _debounceListPanePersist();
  }

  /// Applies a drag [delta] to the logbook list-pane width, clamped to
  /// [minJournalListPaneWidth]..[maxJournalListPaneWidth], and debounces
  /// persistence. Independent of [updateListPaneWidth] so resizing the logbook
  /// does not resize tasks and projects.
  void updateJournalListPaneWidth(double delta) {
    _userAdjusted = true;
    final newWidth = (state.journalListPaneWidth + delta).clamp(
      minJournalListPaneWidth,
      maxJournalListPaneWidth,
    );
    state = state.copyWith(journalListPaneWidth: newWidth);
    _debounceJournalListPanePersist();
  }

  /// Applies a drag [delta] to the docked day-view column's width, clamped to
  /// [minDayViewPanelWidth]..[maxDayViewPanelWidth], and debounces
  /// persistence. Ignored while the column is hidden so its restore width
  /// stays frozen.
  void updateDayViewPanelWidth(double delta) {
    if (state.dayViewPanelHidden) return;
    _userAdjusted = true;
    final newWidth = (state.dayViewPanelWidth + delta).clamp(
      minDayViewPanelWidth,
      maxDayViewPanelWidth,
    );
    state = state.copyWith(dayViewPanelWidth: newWidth);
    _debounceDayViewPanelPersist();
  }

  /// Hides the docked day-view column. `dayViewPanelWidth` is left as-is as
  /// the restore target for [showDayViewPanel] — width drags are refused
  /// while hidden. Persistence is best-effort; see [collapseSidebar].
  void hideDayViewPanel() {
    if (state.dayViewPanelHidden) return;
    _userAdjusted = true;
    _dayViewPanelDebounce?.cancel();
    state = state.copyWith(dayViewPanelHidden: true);
    _persistDayViewPanelWidth();
    _persistDayViewPanelHiddenFlag();
  }

  /// Restores the docked day-view column at its previous width.
  void showDayViewPanel() {
    if (!state.dayViewPanelHidden) return;
    _userAdjusted = true;
    state = state.copyWith(dayViewPanelHidden: false);
    _persistDayViewPanelHiddenFlag();
  }

  /// Toggles the docked day-view column between visible and hidden.
  void toggleDayViewPanelHidden() {
    if (state.dayViewPanelHidden) {
      showDayViewPanel();
    } else {
      hideDayViewPanel();
    }
  }

  /// Collapses the sidebar to the widget's fixed narrow layout.
  ///
  /// `sidebarWidth` is left as-is and will be the restore target when
  /// [expandSidebar] is called — this works because `updateSidebarWidth` is
  /// a no-op while collapsed.
  ///
  /// Persistence is best-effort: the pending debounced width write is
  /// flushed and the new flag is written immediately, but both writes are
  /// fire-and-forget, so an app close within the write's I/O window may
  /// still lose the just-toggled state.
  void collapseSidebar() {
    if (state.sidebarCollapsed) return;
    _userAdjusted = true;
    _sidebarDebounce?.cancel();
    state = state.copyWith(sidebarCollapsed: true);
    _persistSidebarWidth();
    _persistCollapseFlag();
  }

  /// Restores the sidebar to the expanded layout driven by `sidebarWidth`.
  ///
  /// No width mutation is needed — `sidebarWidth` already holds the last
  /// expanded value because it is frozen while collapsed. Persistence is
  /// best-effort; see [collapseSidebar].
  void expandSidebar() {
    if (!state.sidebarCollapsed) return;
    _userAdjusted = true;
    state = state.copyWith(sidebarCollapsed: false);
    _persistCollapseFlag();
  }

  /// Toggles between the collapsed and expanded sidebar layouts.
  void toggleSidebarCollapsed() {
    if (state.sidebarCollapsed) {
      expandSidebar();
    } else {
      collapseSidebar();
    }
  }

  /// Collapses the shared Tasks/Projects list pane without changing its saved
  /// expanded width, so returning from focus mode restores the user's layout.
  void collapseListPane() {
    if (state.listPaneCollapsed) return;
    _userAdjusted = true;
    _listPaneDebounce?.cancel();
    state = state.copyWith(listPaneCollapsed: true);
    _persistListPaneWidth();
    _persistListPaneCollapseFlag();
  }

  /// Restores the shared Tasks/Projects list pane at its previous width.
  void expandListPane() {
    if (!state.listPaneCollapsed) return;
    _userAdjusted = true;
    state = state.copyWith(listPaneCollapsed: false);
    _persistListPaneCollapseFlag();
  }

  /// Toggles the shared Tasks/Projects list pane between browse and focus mode.
  void toggleListPaneCollapsed() {
    if (state.listPaneCollapsed) {
      expandListPane();
    } else {
      collapseListPane();
    }
  }

  void _debounceSidebarPersist() {
    _sidebarDebounce?.cancel();
    _sidebarDebounce = Timer(persistDebounce, _persistSidebarWidth);
  }

  void _debounceListPanePersist() {
    _listPaneDebounce?.cancel();
    _listPaneDebounce = Timer(persistDebounce, _persistListPaneWidth);
  }

  void _debounceJournalListPanePersist() {
    _journalListPaneDebounce?.cancel();
    _journalListPaneDebounce = Timer(
      persistDebounce,
      _persistJournalListPaneWidth,
    );
  }

  void _debounceDayViewPanelPersist() {
    _dayViewPanelDebounce?.cancel();
    _dayViewPanelDebounce = Timer(persistDebounce, _persistDayViewPanelWidth);
  }

  void _persistSidebarWidth() {
    unawaited(_persistWidth(sidebarWidthKey, state.sidebarWidth));
  }

  void _persistListPaneWidth() {
    unawaited(_persistWidth(listPaneWidthKey, state.listPaneWidth));
  }

  void _persistJournalListPaneWidth() {
    unawaited(
      _persistWidth(journalListPaneWidthKey, state.journalListPaneWidth),
    );
  }

  void _persistCollapseFlag() {
    unawaited(
      _persistString(sidebarCollapsedKey, state.sidebarCollapsed.toString()),
    );
  }

  void _persistListPaneCollapseFlag() {
    unawaited(
      _persistString(
        listPaneCollapsedKey,
        state.listPaneCollapsed.toString(),
      ),
    );
  }

  void _persistDayViewPanelWidth() {
    unawaited(_persistWidth(dayViewPanelWidthKey, state.dayViewPanelWidth));
  }

  void _persistDayViewPanelHiddenFlag() {
    unawaited(
      _persistString(
        dayViewPanelHiddenKey,
        state.dayViewPanelHidden.toString(),
      ),
    );
  }

  Future<void> _persistWidth(String key, double width) async {
    await _persistString(key, width.toStringAsFixed(1));
  }

  Future<void> _persistString(String key, String value) async {
    try {
      await getIt<SettingsDb>().saveSettingsItem(key, value);
    } catch (error, stackTrace) {
      debugPrint(
        'PANE_WIDTH persistWidth:$key failed: $error\n$stackTrace',
      );
    }
  }
}
