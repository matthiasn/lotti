import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/sync/state/matrix_login_provider.dart';
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
  final localizations = AppLocalizations.of(context)!;

  return WoltModalSheetPage(
    stickyActionBar: LoggedInPageStickyActionBar(
      pageIndexNotifier: pageIndexNotifier,
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

class LoggedInPageStickyActionBar extends ConsumerWidget {
  const LoggedInPageStickyActionBar({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            key: const Key('matrix_logout'),
            onPressed: () async {
              await ref.read(matrixLoginControllerProvider.notifier).logout();
              pageIndexNotifier.value = 0;
            },
            child: Text(
              localizations.settingsMatrixLogoutButtonLabel,
              semanticsLabel: localizations.settingsMatrixLogoutButtonLabel,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => pageIndexNotifier.value = 2,
            child: Center(
              child: Text(localizations.settingsMatrixNextPage),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeserverLoggedInWidget extends ConsumerStatefulWidget {
  const HomeserverLoggedInWidget({super.key});

  @override
  ConsumerState<HomeserverLoggedInWidget> createState() =>
      _HomeserverLoggedInWidgetState();
}

class _HomeserverLoggedInWidgetState
    extends ConsumerState<HomeserverLoggedInWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final userIdAsyncValue = ref.watch(loggedInUserIdProvider);

    return userIdAsyncValue.map(
      data: (data) {
        final userId = data.valueOrNull;

        if (userId == null) {
          return const CircularProgressIndicator();
        }

        return Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: userId,
                    padding: EdgeInsets.zero,
                    size: 240,
                    key: const Key('QrImage'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(userId, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),
            Text(
              localizations.settingsMatrixQrTextPage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 80),
          ],
        );
      },
      error: (error) {
        return Text(error.valueOrNull.toString());
      },
      loading: (loading) {
        return const CircularProgressIndicator();
      },
    );
  }
}
