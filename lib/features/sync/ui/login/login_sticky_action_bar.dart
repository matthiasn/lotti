import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';
import 'package:lotti/features/sync/state/login_form_controller.dart';
import 'package:lotti/features/sync/state/matrix_config_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class LoginStickyActionBar extends ConsumerWidget {
  const LoginStickyActionBar({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final loginState = ref.watch(loginFormControllerProvider).value;
    final loginNotifier = ref.read(loginFormControllerProvider.notifier);
    final config = ref.watch(matrixConfigControllerProvider).value;

    final enableLoginButton = (loginState?.status.isSuccess ?? false) &&
        !(loginState?.loginFailed ?? false);

    Future<void> deleteConfig() async {
      const deleteKey = 'deleteKey';

      final result = await showModalActionSheet<String>(
        context: context,
        title: context.messages.syncDeleteConfigQuestion,
        actions: [
          ModalSheetAction(
            icon: Icons.warning,
            label: context.messages.syncDeleteConfigConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await loginNotifier.deleteConfig();
      }
    }

    return Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (config != null)
            Flexible(
              child: LottiSecondaryButton(
                key: const Key('matrix_config_delete'),
                label: context.messages.settingsMatrixDeleteLabel,
                onPressed: deleteConfig,
              ),
            ),
          if (config != null) const SizedBox(width: 8),
          Flexible(
            child: LottiPrimaryButton(
              key: const Key('matrix_login'),
              onPressed: enableLoginButton
                  ? () async {
                      final isLoggedIn = await loginNotifier.login();
                      if (isLoggedIn) {
                        pageIndexNotifier.value = 1;
                      }
                    }
                  : null,
              label: context.messages.settingsMatrixLoginButtonLabel,
              semanticsLabel: context.messages.settingsMatrixLoginButtonLabel,
            ),
          ),
        ],
      ),
    );
  }
}
