import 'package:flutter/services.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';

/// The single default command/binding catalog consumed by execution and help.
abstract final class AppCommandCatalog {
  static const List<AppCommandDefinition> definitions = [
    AppCommandDefinition(
      id: AppCommandId.openCommandPalette,
      category: AppCommandCategory.general,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyK),
      ],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.openShortcutHelp,
      category: AppCommandCategory.general,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryCharacter('?'),
        AppShortcutBinding.allKey(LogicalKeyboardKey.f1),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.createTextEntry,
      category: AppCommandCategory.creation,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyN),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.createTask,
      category: AppCommandCategory.creation,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyT),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.captureScreenshot,
      category: AppCommandCategory.creation,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryKey(
          LogicalKeyboardKey.keyS,
          alt: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    ..._navigationDefinitions,
    AppCommandDefinition(
      id: AppCommandId.zoomIn,
      category: AppCommandCategory.view,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryCharacter('+', includeRepeats: true),
        AppShortcutBinding.primaryKey(
          LogicalKeyboardKey.numpadAdd,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.zoomOut,
      category: AppCommandCategory.view,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryCharacter('-', includeRepeats: true),
        AppShortcutBinding.primaryKey(
          LogicalKeyboardKey.numpadSubtract,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.resetZoom,
      category: AppCommandCategory.view,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit0),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.save,
      category: AppCommandCategory.editing,
      context: AppCommandContext.editor,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyS),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.refresh,
      category: AppCommandCategory.view,
      context: AppCommandContext.currentSurface,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyR),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.focusSearch,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.currentSurface,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyF),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.createInContext,
      category: AppCommandCategory.creation,
      context: AppCommandContext.currentSurface,
      bindings: [
        AppShortcutBinding.primaryKey(
          LogicalKeyboardKey.keyN,
          shift: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.nextFocusRegion,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.global,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.f6)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.previousFocusRegion,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.global,
      bindings: [
        AppShortcutBinding.allKey(LogicalKeyboardKey.f6, shift: true),
      ],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    ..._interactionDefinitions,
  ];

  static const List<AppCommandDefinition> _navigationDefinitions = [
    AppCommandDefinition(
      id: AppCommandId.navigateTasks,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit1)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateDailyOs,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit2)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateProjects,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit3)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateHabits,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit4)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateDashboards,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit5)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateJournal,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit6)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateEvents,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit7)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateSettings,
      category: AppCommandCategory.navigation,
      context: AppCommandContext.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit8)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
  ];

  static const List<AppCommandDefinition> _interactionDefinitions = [
    AppCommandDefinition(
      id: AppCommandId.activate,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.enter)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.toggle,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.space)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.rename,
      category: AppCommandCategory.editing,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.f2)],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.delete,
      category: AppCommandCategory.editing,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.delete)],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
      destructive: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.moveUp,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [
        AppShortcutBinding.allKey(
          LogicalKeyboardKey.arrowUp,
          alt: true,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.moveDown,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [
        AppShortcutBinding.allKey(
          LogicalKeyboardKey.arrowDown,
          alt: true,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.cancel,
      category: AppCommandCategory.general,
      context: AppCommandContext.modal,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.escape)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectPrevious,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [
        AppShortcutBinding.allKey(
          LogicalKeyboardKey.arrowUp,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectNext,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [
        AppShortcutBinding.allKey(
          LogicalKeyboardKey.arrowDown,
          includeRepeats: true,
        ),
      ],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
      allowRepeat: true,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectFirst,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.home)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectLast,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.end)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.pageUp,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.pageUp)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.pageDown,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.list,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.pageDown)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.expand,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.tree,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.arrowRight)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.collapse,
      category: AppCommandCategory.listsAndControls,
      context: AppCommandContext.tree,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.arrowLeft)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
  ];

  static final Map<AppCommandId, AppCommandDefinition> _byId = {
    for (final definition in definitions) definition.id: definition,
  };

  static AppCommandDefinition definition(AppCommandId id) => _byId[id]!;

  static Map<Object, AppCommandId> bindingsFor({
    required TargetPlatform platform,
    Iterable<AppCommandId>? commandIds,
  }) {
    final ids = commandIds?.toSet();
    final result = <Object, AppCommandId>{};
    for (final definition in definitions) {
      if (ids != null && !ids.contains(definition.id)) continue;
      for (final binding in definition.bindings) {
        final activator = binding.resolve(platform);
        if (activator != null) result[activator] = definition.id;
      }
    }
    return result;
  }

  /// Finds duplicate bindings in a set of commands that may be active at once.
  static List<AppCommandBindingConflict> conflictsFor({
    required TargetPlatform platform,
    required Iterable<AppCommandId> commandIds,
    Map<AppCommandId, AppCommandDefinition> definitionOverrides = const {},
  }) {
    final seen = <Object, AppCommandId>{};
    final conflicts = <AppCommandBindingConflict>[];
    for (final id in commandIds) {
      final commandDefinition = definitionOverrides[id] ?? definition(id);
      for (final binding in commandDefinition.bindings) {
        final activator = binding.resolve(platform);
        if (activator == null) continue;
        final equivalenceKey = binding.equivalenceKey(platform);
        final existing = seen[equivalenceKey];
        if (existing == null) {
          seen[equivalenceKey] = id;
        } else if (existing != id) {
          conflicts.add(
            AppCommandBindingConflict(
              activator: activator,
              first: existing,
              second: id,
            ),
          );
        }
      }
    }
    return conflicts;
  }
}
