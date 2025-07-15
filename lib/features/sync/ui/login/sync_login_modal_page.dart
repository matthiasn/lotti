import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/login/login_sticky_action_bar.dart';
import 'package:lotti/features/sync/ui/login/sync_login_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage syncLoginModalPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
    title: context.messages.settingsMatrixHomeserverConfigTitle,
    child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
  );
}
