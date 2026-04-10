import 'package:flutter/foundation.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
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

  @override
  PaneWidths build() {
    _loadPersistedWidths();
    return const PaneWidths();
  }

  Future<void> _loadPersistedWidths() async {
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
    _persistSidebarWidth();
  }

  void updateListPaneWidth(double delta) {
    _userAdjusted = true;
    final newWidth = (state.listPaneWidth + delta).clamp(
      minListPaneWidth,
      maxListPaneWidth,
    );
    state = state.copyWith(listPaneWidth: newWidth);
    _persistListPaneWidth();
  }

  void _persistSidebarWidth() {
    getIt<SettingsDb>().saveSettingsItem(
      sidebarWidthKey,
      state.sidebarWidth.toStringAsFixed(1),
    );
  }

  void _persistListPaneWidth() {
    getIt<SettingsDb>().saveSettingsItem(
      listPaneWidthKey,
      state.listPaneWidth.toStringAsFixed(1),
    );
  }

  void resetToDefaults() {
    _userAdjusted = true;
    state = const PaneWidths();
    _persistSidebarWidth();
    _persistListPaneWidth();
  }
}
