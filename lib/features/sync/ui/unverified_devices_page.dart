import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:lotti/widgets/sync/matrix/device_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage unverifiedDevicesPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return WoltModalSheetPage(
    stickyActionBar: Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value - 1,
            child: Center(
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value + 1,
            child: Center(
              child: Text(context.messages.settingsMatrixNextPage),
            ),
          ),
        ],
      ),
    ),
    topBarTitle: Text(
      context.messages.settingsMatrixUnverifiedDevicesPage,
      style: textTheme.titleMedium,
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding) +
          const EdgeInsets.only(bottom: 80),
      child: const UnverifiedDevices(),
    ),
  );
}

class UnverifiedDevices extends ConsumerWidget {
  const UnverifiedDevices({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final unverifiedDevices =
        ref.watch(matrixUnverifiedControllerProvider).value ?? [];

    void refreshList() {
      ref.invalidate(matrixUnverifiedControllerProvider);
    }

    if (unverifiedDevices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.messages.settingsMatrixNoUnverifiedLabel),
          const StatusIndicator(
            Colors.greenAccent,
            semanticsLabel: 'No unverified devices',
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.messages.settingsMatrixListUnverifiedLabel,
              semanticsLabel:
                  context.messages.settingsMatrixListUnverifiedLabel,
            ),
            IconButton(
              key: const Key('matrix_list_unverified'),
              onPressed: refreshList,
              icon: Icon(MdiIcons.refresh),
            ),
          ],
        ),
        ...unverifiedDevices.map(
          (deviceKeys) => DeviceCard(
            deviceKeys,
            refreshListCallback: refreshList,
          ),
        ),
      ],
    );
  }
}
