import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/login/sync_login_modal_page.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/features/sync/ui/matrix_stats_page.dart';
import 'package:lotti/features/sync/ui/room_config_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/settings/animated_settings_cards.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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

        WoltModalSheet.show<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalSheetContext) {
            final textTheme = context.textTheme;
            return [
              syncLoginModalPage(
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
          modalTypeBuilder: ModalUtils.modalTypeBuilder,
          barrierDismissible: true,
        );
      },
    );
  }
}
