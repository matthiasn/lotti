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

/// State holding the current widths and collapsed flag for the sidebar, plus
/// the width for the list pane.
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
    this.sidebarCollapsed = false,
  });

  final double sidebarWidth;
  final double listPaneWidth;
  final double journalListPaneWidth;
  final bool sidebarCollapsed;

  PaneWidths copyWith({
    double? sidebarWidth,
    double? listPaneWidth,
    double? journalListPaneWidth,
    bool? sidebarCollapsed,
  }) {
    return PaneWidths(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      listPaneWidth: listPaneWidth ?? this.listPaneWidth,
      journalListPaneWidth: journalListPaneWidth ?? this.journalListPaneWidth,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
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
          sidebarCollapsed == other.sidebarCollapsed;

  @override
  int get hashCode => Object.hash(
    sidebarWidth,
    listPaneWidth,
    journalListPaneWidth,
    sidebarCollapsed,
  );
}

/// Keep-alive Riverpod notifier owning the resizable sidebar and list-pane
/// widths and the sidebar's collapsed flag.
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

  @override
  PaneWidths build() {
    ref.onDispose(() {
      _sidebarDebounce?.cancel();
      _listPaneDebounce?.cancel();
      _journalListPaneDebounce?.cancel();
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
        sidebarCollapsedKey,
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
      final sidebarCollapsed = values[sidebarCollapsedKey] == 'true';

      state = PaneWidths(
        sidebarWidth: sidebarWidth,
        listPaneWidth: listPaneWidth,
        journalListPaneWidth: journalListPaneWidth,
        sidebarCollapsed: sidebarCollapsed,
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
  void updateListPaneWidth(double delta) {
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

  /// Resets all widths and the collapsed flag to their defaults, cancels any
  /// pending debounced writes, and persists the defaults.
  void resetToDefaults() {
    _userAdjusted = true;
    _sidebarDebounce?.cancel();
    _listPaneDebounce?.cancel();
    _journalListPaneDebounce?.cancel();
    state = const PaneWidths();
    _persistSidebarWidth();
    _persistListPaneWidth();
    _persistJournalListPaneWidth();
    _persistCollapseFlag();
  }
}
