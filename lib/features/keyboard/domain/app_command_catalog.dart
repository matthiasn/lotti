import 'package:flutter/services.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';

/// The single default command/binding catalog consumed by execution and help.
abstract final class AppCommandCatalog {
  static const List<AppCommandDefinition> definitions = [
    AppCommandDefinition(
      id: AppCommandId.openCommandPalette,
      category: AppCommandCategory.general,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyK),
      ],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.openShortcutHelp,
      category: AppCommandCategory.general,
      bindings: [
        AppShortcutBinding.primaryCharacter('?'),
        AppShortcutBinding.allKey(LogicalKeyboardKey.f1),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.createTextEntry,
      category: AppCommandCategory.creation,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyN),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.createTask,
      category: AppCommandCategory.creation,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyT),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.captureScreenshot,
      category: AppCommandCategory.creation,
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
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit0),
      ],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.save,
      category: AppCommandCategory.editing,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyS),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.refresh,
      category: AppCommandCategory.view,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyR),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.focusSearch,
      category: AppCommandCategory.navigation,
      bindings: [
        AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyF),
      ],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.createInContext,
      category: AppCommandCategory.creation,
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
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.f6)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.previousFocusRegion,
      category: AppCommandCategory.navigation,
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
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit1)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateDailyOs,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit2)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateProjects,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit3)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateHabits,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit4)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateDashboards,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit5)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateJournal,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit6)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateEvents,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit7)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
    AppCommandDefinition(
      id: AppCommandId.navigateSettings,
      category: AppCommandCategory.navigation,
      bindings: [AppShortcutBinding.primaryKey(LogicalKeyboardKey.digit8)],
      paletteVisibility: AppCommandPaletteVisibility.global,
    ),
  ];

  static const List<AppCommandDefinition> _interactionDefinitions = [
    AppCommandDefinition(
      id: AppCommandId.activate,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.enter)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.toggle,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.space)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.rename,
      category: AppCommandCategory.editing,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.f2)],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.delete,
      category: AppCommandCategory.editing,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.delete)],
      paletteVisibility: AppCommandPaletteVisibility.activeContext,
    ),
    AppCommandDefinition(
      id: AppCommandId.moveUp,
      category: AppCommandCategory.listsAndControls,
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
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.escape)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectPrevious,
      category: AppCommandCategory.listsAndControls,
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
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.home)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.selectLast,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.end)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.pageUp,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.pageUp)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.pageDown,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.pageDown)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.expand,
      category: AppCommandCategory.listsAndControls,
      bindings: [AppShortcutBinding.allKey(LogicalKeyboardKey.arrowRight)],
      paletteVisibility: AppCommandPaletteVisibility.hidden,
    ),
    AppCommandDefinition(
      id: AppCommandId.collapse,
      category: AppCommandCategory.listsAndControls,
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
}
