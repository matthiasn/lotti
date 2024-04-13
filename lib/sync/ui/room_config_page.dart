import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage roomConfigPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  final localizations = AppLocalizations.of(context)!;

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
              child: Text(localizations.settingsMatrixPreviousPage),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                pageIndexNotifier.value = pageIndexNotifier.value + 1,
            child: Center(
              child: Text(localizations.settingsMatrixNextPage),
            ),
          ),
        ],
      ),
    ),
    topBarTitle: Text(
      localizations.settingsMatrixRoomConfigTitle,
      style: textTheme.titleMedium,
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: const SizedBox(
      height: 300,
      child: Column(),
    ),
  );
}
