import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';
import 'package:lotti/features/sync/state/login_form_controller.dart';
import 'package:lotti/features/sync/state/matrix_config_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
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
    final loginState = ref.watch(loginFormControllerProvider).valueOrNull;
    final loginNotifier = ref.read(loginFormControllerProvider.notifier);
    final config = ref.watch(matrixConfigControllerProvider).valueOrNull;

    final enableLoginButton = loginState?.status.isSuccess ?? false;

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
            isDefaultAction: true,
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
            OutlinedButton(
              key: const Key('matrix_config_delete'),
              onPressed: deleteConfig,
              child: Text(
                context.messages.settingsMatrixDeleteLabel,
                style: TextStyle(
                  color: context.colorScheme.error,
                ),
                semanticsLabel: 'Delete Matrix Config',
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('matrix_login'),
            onPressed: enableLoginButton
                ? () async {
                    final isLoggedIn = await loginNotifier.login();
                    if (isLoggedIn) {
                      pageIndexNotifier.value = 1;
                    }
                  }
                : null,
            child: Text(
              context.messages.settingsMatrixLoginButtonLabel,
              semanticsLabel: context.messages.settingsMatrixLoginButtonLabel,
            ),
          ),
        ],
      ),
    );
  }
}
