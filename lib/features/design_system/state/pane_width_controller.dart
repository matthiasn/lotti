import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pane_width_controller.g.dart';

/// Settings keys for persisted pane widths.
const sidebarWidthKey = 'PANE_WIDTH_SIDEBAR';
const listPaneWidthKey = 'PANE_WIDTH_LIST';
const sidebarCollapsedKey = 'PANE_WIDTH_SIDEBAR_COLLAPSED';

/// Default and constraint values for pane widths.
const defaultSidebarWidth = 320.0;
const minSidebarWidth = 200.0;
const maxSidebarWidth = 500.0;

const defaultListPaneWidth = 540.0;
const minListPaneWidth = 300.0;
const maxListPaneWidth = 800.0;

/// How long to wait after the last drag update before persisting to disk.
@visibleForTesting
const persistDebounce = Duration(milliseconds: 300);

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
    this.sidebarCollapsed = false,
  });

  final double sidebarWidth;
  final double listPaneWidth;
  final bool sidebarCollapsed;

  PaneWidths copyWith({
    double? sidebarWidth,
    double? listPaneWidth,
    bool? sidebarCollapsed,
  }) {
    return PaneWidths(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      listPaneWidth: listPaneWidth ?? this.listPaneWidth,
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
          sidebarCollapsed == other.sidebarCollapsed;

  @override
  int get hashCode => Object.hash(
    sidebarWidth,
    listPaneWidth,
    sidebarCollapsed,
  );
}

@Riverpod(keepAlive: true)
class PaneWidthController extends _$PaneWidthController {
  bool _userAdjusted = false;
  Timer? _sidebarDebounce;
  Timer? _listPaneDebounce;

  @override
  PaneWidths build() {
    ref.onDispose(() {
      _sidebarDebounce?.cancel();
      _listPaneDebounce?.cancel();
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
      final sidebarCollapsed = values[sidebarCollapsedKey] == 'true';

      state = PaneWidths(
        sidebarWidth: sidebarWidth,
        listPaneWidth: listPaneWidth,
        sidebarCollapsed: sidebarCollapsed,
      );
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'PANE_WIDTH',
        subDomain: 'loadPersistedWidths',
        stackTrace: stackTrace,
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

  void updateListPaneWidth(double delta) {
    _userAdjusted = true;
    final newWidth = (state.listPaneWidth + delta).clamp(
      minListPaneWidth,
      maxListPaneWidth,
    );
    state = state.copyWith(listPaneWidth: newWidth);
    _debounceListPanePersist();
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

  void _persistSidebarWidth() {
    unawaited(_persistWidth(sidebarWidthKey, state.sidebarWidth));
  }

  void _persistListPaneWidth() {
    unawaited(_persistWidth(listPaneWidthKey, state.listPaneWidth));
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
      getIt<LoggingService>().captureException(
        error,
        domain: 'PANE_WIDTH',
        subDomain: 'persistWidth:$key',
        stackTrace: stackTrace,
      );
    }
  }

  void resetToDefaults() {
    _userAdjusted = true;
    _sidebarDebounce?.cancel();
    _listPaneDebounce?.cancel();
    state = const PaneWidths();
    _persistSidebarWidth();
    _persistListPaneWidth();
    _persistCollapseFlag();
  }
}
