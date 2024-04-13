import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServerKey = 'home_server';
const matrixRoomIdKey = 'room_id';

SliverWoltModalSheetPage homeServerLoggedInPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  final matrixService = getIt<MatrixService>();

  final localizations = AppLocalizations.of(context)!;

  return WoltModalSheetPage(
    stickyActionBar: Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            key: const Key('matrix_logout'),
            onPressed: () {
              pageIndexNotifier.value = 0;
              matrixService.logout();
            },
            child: Text(
              localizations.settingsMatrixLogoutButtonLabel,
              semanticsLabel: localizations.settingsMatrixLogoutButtonLabel,
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
      localizations.settingsMatrixHomeserverConfigTitle,
      style: textTheme.titleMedium,
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: const Padding(
      padding: EdgeInsets.all(WoltModalConfig.pagePadding),
      child: HomeserverLoggedInWidget(),
    ),
  );
}

class HomeserverLoggedInWidget extends ConsumerStatefulWidget {
  const HomeserverLoggedInWidget({super.key});

  @override
  ConsumerState<HomeserverLoggedInWidget> createState() =>
      _HomeserverLoggedInWidgetState();
}

class _HomeserverLoggedInWidgetState
    extends ConsumerState<HomeserverLoggedInWidget> {
  final _matrixService = getIt<MatrixService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final userId = _matrixService.client.userID;

    return Column(
      children: [
        const SizedBox(height: 20),
        if (userId != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: userId,
                  padding: EdgeInsets.zero,
                  size: 280,
                  key: const Key('QrImage'),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          '${_matrixService.client.userID}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        Text(
          localizations.settingsMatrixQrTextPage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
