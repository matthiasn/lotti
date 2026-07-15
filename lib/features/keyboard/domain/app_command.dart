import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_shortcut_binding.dart';

export 'package:lotti/features/keyboard/domain/app_shortcut_binding.dart';

/// Stable identifiers for every command exposed by Lotti's desktop keyboard
/// system.
///
/// IDs are behavior-level contracts: UI labels, default bindings, command
/// palette rows, native menu entries, and contextual handlers all refer to the
/// same value. Renaming a label therefore never changes command identity.
enum AppCommandId {
  openCommandPalette,
  openShortcutHelp,
  createTextEntry,
  createTask,
  captureScreenshot,
  navigateTasks,
  navigateDailyOs,
  navigateProjects,
  navigateHabits,
  navigateDashboards,
  navigateJournal,
  navigateEvents,
  navigateSettings,
  zoomIn,
  zoomOut,
  resetZoom,
  save,
  refresh,
  focusSearch,
  createInContext,
  nextFocusRegion,
  previousFocusRegion,
  activate,
  toggle,
  rename,
  delete,
  moveUp,
  moveDown,
  cancel,
  selectPrevious,
  selectNext,
  selectFirst,
  selectLast,
  pageUp,
  pageDown,
  expand,
  collapse,
}

/// User-facing grouping used by shortcut help and command-palette ranking.
enum AppCommandCategory {
  general,
  creation,
  navigation,
  view,
  editing,
  listsAndControls,
}

/// The kind of focused surface in which a command is meaningful.
enum AppCommandContext {
  global,
  currentSurface,
  navigation,
  list,
  tree,
  editor,
  modal,
  calendar,
  imageViewer,
  resizablePane,
}

/// Whether a command should be offered by the command palette.
enum AppCommandPaletteVisibility {
  /// The command is supplied by the app-global scope.
  global,

  /// Show the command only when an active scope supplies an enabled handler.
  activeContext,

  /// Interaction grammar that belongs in help but would be noisy in a palette.
  hidden,
}

/// Intent produced by every catalog shortcut and resolved by the command host.
class AppCommandIntent extends Intent {
  const AppCommandIntent(this.id);

  final AppCommandId id;
}

/// Immutable command metadata independent of localization and handler state.
@immutable
class AppCommandDefinition {
  const AppCommandDefinition({
    required this.id,
    required this.category,
    required this.context,
    required this.bindings,
    required this.paletteVisibility,
    this.destructive = false,
    this.allowRepeat = false,
  });

  final AppCommandId id;
  final AppCommandCategory category;
  final AppCommandContext context;
  final List<AppShortcutBinding> bindings;
  final AppCommandPaletteVisibility paletteVisibility;
  final bool destructive;

  /// Whether holding the shortcut may invoke the command repeatedly.
  ///
  /// One-shot commands such as create/save keep the default `false`; zoom,
  /// resize, and movement commands opt in explicitly.
  final bool allowRepeat;
}

/// A duplicate platform binding in a set of simultaneously active commands.
@immutable
class AppCommandBindingConflict {
  const AppCommandBindingConflict({
    required this.activator,
    required this.first,
    required this.second,
  });

  final Object activator;
  final AppCommandId first;
  final AppCommandId second;
}
