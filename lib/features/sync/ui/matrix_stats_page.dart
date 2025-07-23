import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage matrixStatsPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LottiSecondaryButton(
            label: context.messages.settingsMatrixPreviousPage,
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value - 1,
          ),
          const SizedBox(height: 8),
          LottiPrimaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.settingsMatrixDone,
          ),
        ],
      ),
    ),
    title: context.messages.settingsMatrixStatsTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const IncomingStats(),
  );
}

class IncomingStats extends ConsumerWidget {
  const IncomingStats({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final stats = ref.watch(matrixStatsControllerProvider);

    return stats.map(
      data: (data) {
        final value = data.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent messages: ${value.sentCount}'),
            const SizedBox(height: 10),
            DataTable(
              columns: const <DataColumn>[
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Message Type',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Count',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
              rows: <DataRow>[
                ...value.messageCounts.keys.map(
                  (k) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(k)),
                      DataCell(Text(value.messageCounts[k].toString())),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
      error: (error) => const CircularProgressIndicator(),
      loading: (loading) => const CircularProgressIndicator(),
    );
  }
}
