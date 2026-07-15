import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Localized presentation for command metadata.
///
/// The app command catalog owns identity and bindings; every surface that
/// displays a command resolves its copy through this class so menus, the
/// palette, and shortcut help agree.
abstract final class AppCommandText {
  static String label(AppLocalizations messages, AppCommandId id) {
    return switch (id) {
      AppCommandId.openCommandPalette => messages.keyboardCommandOpenPalette,
      AppCommandId.openShortcutHelp => messages.keyboardShortcutsTitle,
      AppCommandId.createTextEntry => messages.fileMenuNewEntry,
      AppCommandId.createTask => messages.fileMenuNewTask,
      AppCommandId.captureScreenshot => messages.fileMenuNewScreenshot,
      AppCommandId.navigateTasks => messages.keyboardCommandNavigate(
        messages.navTabTitleTasks,
      ),
      AppCommandId.navigateDailyOs => messages.keyboardCommandNavigate(
        messages.navTabTitleCalendar,
      ),
      AppCommandId.navigateProjects => messages.keyboardCommandNavigate(
        messages.navTabTitleProjects,
      ),
      AppCommandId.navigateHabits => messages.keyboardCommandNavigate(
        messages.navTabTitleHabits,
      ),
      AppCommandId.navigateDashboards => messages.keyboardCommandNavigate(
        messages.navTabTitleInsights,
      ),
      AppCommandId.navigateJournal => messages.keyboardCommandNavigate(
        messages.navTabTitleJournal,
      ),
      AppCommandId.navigateEvents => messages.keyboardCommandNavigate(
        messages.navTabTitleEvents,
      ),
      AppCommandId.navigateSettings => messages.keyboardCommandNavigate(
        messages.navTabTitleSettings,
      ),
      AppCommandId.zoomIn => messages.viewMenuZoomIn,
      AppCommandId.zoomOut => messages.viewMenuZoomOut,
      AppCommandId.resetZoom => messages.viewMenuZoomReset,
      AppCommandId.save => messages.saveButton,
      AppCommandId.refresh => messages.keyboardCommandRefresh,
      AppCommandId.focusSearch => messages.keyboardCommandFocusSearch,
      AppCommandId.createInContext => messages.keyboardCommandCreateInContext,
      AppCommandId.nextFocusRegion => messages.keyboardCommandNextRegion,
      AppCommandId.previousFocusRegion =>
        messages.keyboardCommandPreviousRegion,
      AppCommandId.activate => messages.keyboardCommandActivate,
      AppCommandId.toggle => messages.keyboardCommandToggle,
      AppCommandId.rename => messages.keyboardCommandRename,
      AppCommandId.delete => messages.deleteButton,
      AppCommandId.moveUp => messages.keyboardCommandMoveUp,
      AppCommandId.moveDown => messages.keyboardCommandMoveDown,
      AppCommandId.cancel => messages.cancelButton,
      AppCommandId.selectPrevious => messages.keyboardCommandSelectPrevious,
      AppCommandId.selectNext => messages.keyboardCommandSelectNext,
      AppCommandId.selectFirst => messages.keyboardCommandSelectFirst,
      AppCommandId.selectLast => messages.keyboardCommandSelectLast,
      AppCommandId.pageUp => messages.keyboardCommandPageUp,
      AppCommandId.pageDown => messages.keyboardCommandPageDown,
      AppCommandId.expand => messages.checklistExpandTooltip,
      AppCommandId.collapse => messages.checklistCollapseTooltip,
    };
  }

  static String category(
    AppLocalizations messages,
    AppCommandCategory category,
  ) {
    return switch (category) {
      AppCommandCategory.general => messages.keyboardCommandCategoryGeneral,
      AppCommandCategory.creation => messages.keyboardCommandCategoryCreation,
      AppCommandCategory.navigation =>
        messages.keyboardCommandCategoryNavigation,
      AppCommandCategory.view => messages.keyboardCommandCategoryView,
      AppCommandCategory.editing => messages.keyboardCommandCategoryEditing,
      AppCommandCategory.listsAndControls =>
        messages.keyboardCommandCategoryListsAndControls,
    };
  }
}
