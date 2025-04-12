import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/login/login_sticky_action_bar.dart';
import 'package:lotti/features/sync/ui/login/sync_login_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage syncLoginModalPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return WoltModalSheetPage(
    stickyActionBar: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
    topBarTitle: Text(
      context.messages.settingsMatrixHomeserverConfigTitle,
      style: textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.outline),
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: Icon(Icons.close, color: context.colorScheme.outline),
      onPressed: Navigator.of(context).pop,
    ),
    child: Padding(
      padding: WoltModalConfig.pagePadding,
      child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
    ),
  );
}
