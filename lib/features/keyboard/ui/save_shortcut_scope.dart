import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:material_ui/material_ui.dart';

bool _alwaysEnabled() => true;

/// Binds the catalog-driven save command (Cmd/Ctrl+S) to [onSave] for
/// everything below it.
///
/// Editors wrap their page in it, so shared page shells such as
/// `SettingsDetailScaffold` stay free of the keyboard feature.
class SaveShortcutScope extends StatelessWidget {
  const SaveShortcutScope({
    required this.onSave,
    required this.child,
    this.isEnabled = _alwaysEnabled,
    super.key,
  });

  /// Invoked by the save command. Usually the same handler as the page's
  /// primary save action.
  final VoidCallback onSave;

  /// Resolves save-command availability when the command is queried.
  ///
  /// A predicate keeps the command state aligned with live form state without
  /// requiring the command scope itself to be replaced.
  final ValueGetter<bool> isEnabled;

  final Widget child;

  @override
  Widget build(BuildContext context) => AppCommandScope(
    handlers: {
      AppCommandId.save: AppCommandHandler(
        isEnabled: isEnabled,
        invoke: (_) => onSave(),
      ),
    },
    child: child,
  );
}
