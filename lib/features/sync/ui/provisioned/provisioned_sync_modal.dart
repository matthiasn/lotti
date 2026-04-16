import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ProvisionedSyncSettingsCard extends ConsumerStatefulWidget {
  const ProvisionedSyncSettingsCard({
    required this.showDivider,
    super.key,
  });

  final bool showDivider;

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DesignSystemListItem(
      title: context.messages.provisionedSyncTitle,
      subtitle: context.messages.provisionedSyncSubtitle,
      leading: const SettingsIcon(icon: Icons.qr_code_scanner),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: tokens.spacing.step6,
        color: tokens.colors.text.lowEmphasis,
      ),
      showDivider: widget.showDivider,
      dividerIndent: SettingsIcon.dividerIndent(tokens),
      onTap: () {
        final matrixService = ref.read(matrixServiceProvider);
        final isConfigured =
            matrixService.isLoggedIn() && matrixService.syncRoomId != null;
        pageIndexNotifier.value = 0;

        ModalUtils.showMultiPageModal<void>(
          context: context,
          pageIndexNotifier: pageIndexNotifier,
          pageListBuilder: (modalContext) {
            if (isConfigured) {
              return [
                provisionedStatusPage(
                  context: modalContext,
                  pageIndexNotifier: pageIndexNotifier,
                ),
              ];
            }

            return [
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
            ];
          },
        );
      },
    );
  }
}
