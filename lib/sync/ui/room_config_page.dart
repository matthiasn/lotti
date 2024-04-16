import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
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
    child: Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding) +
          const EdgeInsets.only(bottom: 80),
      child: const RoomSetup(),
    ),
  );
}

class RoomSetup extends ConsumerWidget {
  const RoomSetup({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final matrixService = getIt<MatrixService>();

    return Column(
      children: [
        OutlinedButton(
          key: const Key('matrix_create_room'),
          onPressed: () async {
            await matrixService.createRoom();
          },
          child: const Text('Create room'),
        ),
      ],
    );
  }
}
