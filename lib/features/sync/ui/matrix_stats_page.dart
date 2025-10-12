import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/matrix_stats/incoming_stats.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

export 'matrix_stats/incoming_stats.dart';

SliverWoltModalSheetPage matrixStatsPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        padding: WoltModalConfig.pagePadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: LottiSecondaryButton(
                label: context.messages.settingsMatrixPreviousPage,
                onPressed: () =>
                    pageIndexNotifier.value = pageIndexNotifier.value - 1,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LottiPrimaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: context.messages.settingsMatrixDone,
              ),
            ),
          ],
        ),
      ),
    ),
    title: context.messages.settingsMatrixStatsTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const IncomingStats(),
  );
}
