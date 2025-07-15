import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/login/sync_login_modal_page.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats_page.dart';
import 'package:lotti/features/sync/ui/room_config_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class MatrixSettingsCard extends StatelessWidget {
  const MatrixSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pageIndexNotifier = ValueNotifier(0);

    return AnimatedModernSettingsCardWithIcon(
      title: context.messages.settingsMatrixTitle,
      subtitle: 'Configure end-to-end encrypted sync',
      icon: Icons.sync,
      onTap: () {
        if (getIt<MatrixService>().isLoggedIn()) {
          pageIndexNotifier.value = 1;
        } else {
          pageIndexNotifier.value = 0;
        }

        ModalUtils.showMultiPageModal<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalSheetContext) => [
            syncLoginModalPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            homeServerLoggedInPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            roomConfigPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            unverifiedDevicesPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            matrixStatsPage(
              context: modalSheetContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ],
        );
      },
    );
  }
}
