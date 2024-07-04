import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/ui/homeserver_config_page.dart';
import 'package:lotti/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/sync/ui/matrix_stats_page.dart';
import 'package:lotti/sync/ui/room_config_page.dart';
import 'package:lotti/sync/ui/unverified_devices_page.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class MatrixSettingsCard extends StatelessWidget {
  const MatrixSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pageIndexNotifier = ValueNotifier(0);

    return SettingsCard(
      title: context.messages.settingsMatrixTitle,
      onTap: () {
        if (getIt<MatrixService>().isLoggedIn()) {
          pageIndexNotifier.value = 1;
        } else {
          pageIndexNotifier.value = 0;
        }

        WoltModalSheet.show<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalSheetContext) {
            final textTheme = Theme.of(context).textTheme;
            return [
              homeServerConfigPage(
                context: modalSheetContext,
                textTheme: textTheme,
                pageIndexNotifier: pageIndexNotifier,
              ),
              homeServerLoggedInPage(
                context: modalSheetContext,
                textTheme: textTheme,
                pageIndexNotifier: pageIndexNotifier,
              ),
              roomConfigPage(
                context: modalSheetContext,
                textTheme: textTheme,
                pageIndexNotifier: pageIndexNotifier,
              ),
              unverifiedDevicesPage(
                context: modalSheetContext,
                textTheme: textTheme,
                pageIndexNotifier: pageIndexNotifier,
              ),
              matrixStatsPage(
                context: modalSheetContext,
                textTheme: textTheme,
                pageIndexNotifier: pageIndexNotifier,
              ),
            ];
          },
          modalTypeBuilder: (context) {
            final size = MediaQuery.of(context).size.width;
            if (size < WoltModalConfig.pageBreakpoint) {
              return WoltModalType.bottomSheet();
            } else {
              return WoltModalType.dialog();
            }
          },
          onModalDismissedWithBarrierTap: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
