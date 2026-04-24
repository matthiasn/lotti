import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';

/// Detail-pane placeholder shown while the real panel registry from
/// plan step 5 is not wired up yet.
///
/// Two states:
/// - Empty path → localized "pick a section" message.
/// - Selected path → localized "panel not yet implemented" copy plus
///   the leaf/branch id as a developer hint.
///
/// Both states render a persistent "Disable Settings V2" button.
/// This is the escape hatch from the Step 3 bug where a user could
/// flip the flag on and be stranded on a blank page with no way
/// back to the legacy column-stack (which is where the Flags page
/// — and therefore the toggle itself — lives).
class SettingsV2DetailPlaceholder extends ConsumerWidget {
  const SettingsV2DetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final path = ref.watch(settingsTreePathProvider);
    final textHi = tokens.colors.text.highEmphasis;
    final textMid = tokens.colors.text.mediumEmphasis;

    final body = path.isEmpty
        ? _EmptyRoot(textHi: textHi, textMid: textMid, tokens: tokens)
        : _UnimplementedPanel(
            leafId: path.last,
            textHi: textHi,
            textMid: textMid,
            tokens: tokens,
          );

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: body)),
          const _DisableV2Button(),
        ],
      ),
    );
  }
}

class _EmptyRoot extends StatelessWidget {
  const _EmptyRoot({
    required this.textHi,
    required this.textMid,
    required this.tokens,
  });

  final Color textHi;
  final Color textMid;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.settings_outlined,
          size: SettingsV2Constants.placeholderIconSize,
          color: textMid,
        ),
        SizedBox(height: tokens.spacing.step4),
        Text(
          context.messages.navTabTitleSettings,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: textHi,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          context.messages.settingsV2EmptyStateBody,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: textMid,
          ),
        ),
      ],
    );
  }
}

class _UnimplementedPanel extends StatelessWidget {
  const _UnimplementedPanel({
    required this.leafId,
    required this.textHi,
    required this.textMid,
    required this.tokens,
  });

  final String leafId;
  final Color textHi;
  final Color textMid;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.construction_rounded,
          size: SettingsV2Constants.placeholderIconSize,
          color: textMid,
        ),
        SizedBox(height: tokens.spacing.step4),
        Text(
          context.messages.settingsV2UnimplementedTitle,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: textHi,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          leafId,
          style: tokens.typography.styles.others.caption.copyWith(
            color: textMid,
          ),
        ),
      ],
    );
  }
}

class _DisableV2Button extends ConsumerWidget {
  const _DisableV2Button();

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
        onPressed: () => _disableSettingsV2(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.colors.text.highEmphasis,
          side: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
    );
  }

  /// Writes `status=false` for [enableSettingsTreeFlag] without
  /// duplicating the flag's description literal — instead we fetch
  /// the flag row that `initConfigFlags` registered and copy it with
  /// the status flipped off. Keeps the on-disk description in sync
  /// with whatever the canonical registration declared.
  ///
  /// If the row somehow isn't present (e.g. DB never initialized),
  /// we fall back to a fresh `ConfigFlag` literal so the escape
  /// hatch still works — a missing flag row is already the same as
  /// status false, but writing explicitly guarantees the Flags page
  /// shows a consistent toggle state afterwards.
  ///
  /// Errors are logged and surfaced to the user via snackbar: this
  /// is the escape hatch, so silent failure would strand the user
  /// on a blank page with no recourse.
  Future<void> _disableSettingsV2(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failureMessage = context.messages.settingsV2DisableFailed;
    try {
      final db = getIt<JournalDb>();
      final existing = await db.getConfigFlagByName(enableSettingsTreeFlag);
      final next = existing != null
          ? existing.copyWith(status: false)
          : const ConfigFlag(
              name: enableSettingsTreeFlag,
              description: '',
              status: false,
            );
      await getIt<PersistenceLogic>().setConfigFlag(next);
      // No navigation needed: the provider watch in SettingsRootPage
      // reacts to the flag change and re-mounts the legacy column
      // stack on the next frame.
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
