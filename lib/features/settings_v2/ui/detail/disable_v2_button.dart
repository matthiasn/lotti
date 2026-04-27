import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';

/// Escape hatch button that flips [enableSettingsTreeFlag] off.
///
/// Surfaced inside the empty-root and default-panel detail states
/// so a user who enabled Settings V2 before any real panel was
/// wired up can always get back to the legacy column-stack (which
/// hosts the Flags page — and therefore the toggle — in v1). Once
/// the flag goes default-on and the legacy branch is deleted this
/// widget goes with it.
class DisableV2Button extends ConsumerWidget {
  const DisableV2Button({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        icon: const Icon(
          Icons.undo_rounded,
          size: SettingsV2Constants.placeholderButtonIconSize,
        ),
        label: Text(context.messages.settingsV2DisableAction),
        onPressed: () => _disable(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.colors.text.highEmphasis,
          side: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
    );
  }

  /// Reads the existing flag row (so the DB-side description stays
  /// in sync with the canonical registration in
  /// `initConfigFlags`) and writes `status=false`. If the row isn't
  /// present — a theoretical "DB never initialised" edge — we fall
  /// back to writing a fresh `ConfigFlag` literal so the escape
  /// hatch still produces the intended effect rather than silently
  /// no-oping. Any error is logged and surfaced via a snackbar
  /// because this is the last-resort path out of a blank V2 UI.
  Future<void> _disable(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failureMessage = context.messages.settingsV2DisableFailed;
    try {
      final db = getIt<JournalDb>();
      final existing = await db.getConfigFlagByName(enableSettingsTreeFlag);
      final next = existing != null
          ? existing.copyWith(status: false)
          : const ConfigFlag(
              name: enableSettingsTreeFlag,
              description: enableSettingsTreeFlagDescription,
              status: false,
            );
      await getIt<PersistenceLogic>().setConfigFlag(next);
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'SETTINGS_V2',
        subDomain: 'disableEscapeHatch',
        stackTrace: stackTrace,
      );
      messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
}
