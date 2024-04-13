import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/sync/ui/homeserver_config_page.dart';
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

    final localizations = AppLocalizations.of(context)!;
    return SettingsCard(
      title: localizations.settingsMatrixTitle,
      onTap: () {
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
            ];
          },
          modalTypeBuilder: (context) {
            final size = MediaQuery.of(context).size.width;
            if (size < WoltModalConfig.pageBreakpoint) {
              return WoltModalType.bottomSheet;
            } else {
              return WoltModalType.dialog;
            }
          },
          onModalDismissedWithBarrierTap: () {
            Navigator.of(context).pop();
          },
          maxDialogWidth: WoltModalConfig.maxDialogWidth,
          minDialogWidth: WoltModalConfig.minDialogWidth,
          minPageHeight: WoltModalConfig.minPageHeight,
          maxPageHeight: WoltModalConfig.maxPageHeight,
        );
      },
    );
  }
}
