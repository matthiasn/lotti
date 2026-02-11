import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ProvisionedSyncSettingsCard extends ConsumerStatefulWidget {
  const ProvisionedSyncSettingsCard({super.key});

  @override
  ConsumerState<ProvisionedSyncSettingsCard> createState() =>
      _ProvisionedSyncSettingsCardState();
}

class _ProvisionedSyncSettingsCardState
    extends ConsumerState<ProvisionedSyncSettingsCard> {
  late final ValueNotifier<int> pageIndexNotifier;

  @override
  void initState() {
    super.initState();
    pageIndexNotifier = ValueNotifier(0);
  }

  @override
  void dispose() {
    pageIndexNotifier.dispose();
    super.dispose();
  }

  void _updatePageIndex() {
    final matrixService = ref.read(matrixServiceProvider);
    if (matrixService.isLoggedIn() && matrixService.syncRoomId != null) {
      pageIndexNotifier.value = 2;
    } else {
      pageIndexNotifier.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedModernSettingsCardWithIcon(
      title: context.messages.provisionedSyncTitle,
      subtitle: context.messages.provisionedSyncSubtitle,
      icon: Icons.qr_code_scanner,
      onTap: () {
        _updatePageIndex();
        ModalUtils.showMultiPageModal<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalContext) => [
            bundleImportPage(
              context: modalContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            provisionedConfigPage(
              context: modalContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
            provisionedStatusPage(
              context: modalContext,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ],
        );
      },
    );
  }
}
