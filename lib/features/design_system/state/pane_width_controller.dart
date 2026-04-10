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

/// State holding the current widths for the sidebar and list pane.
@immutable
class PaneWidths {
  const PaneWidths({
    this.sidebarWidth = defaultSidebarWidth,
    this.listPaneWidth = defaultListPaneWidth,
  });

  final double sidebarWidth;
  final double listPaneWidth;

  PaneWidths copyWith({
    double? sidebarWidth,
    double? listPaneWidth,
  }) {
    return PaneWidths(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      listPaneWidth: listPaneWidth ?? this.listPaneWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneWidths &&
          runtimeType == other.runtimeType &&
          sidebarWidth == other.sidebarWidth &&
          listPaneWidth == other.listPaneWidth;

  @override
  int get hashCode => Object.hash(sidebarWidth, listPaneWidth);
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

      state = PaneWidths(
        sidebarWidth: sidebarWidth,
        listPaneWidth: listPaneWidth,
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
    if (parsed == null) return defaultValue;
    return parsed.clamp(minValue, maxValue);
  }

  void updateSidebarWidth(double delta) {
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

  Future<void> _persistWidth(String key, double width) async {
    try {
      await getIt<SettingsDb>().saveSettingsItem(
        key,
        width.toStringAsFixed(1),
      );
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
  }
}
