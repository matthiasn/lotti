import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/models/matrix_credentials_input.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/sync_setup_entry.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// The Linux-only entry to the setup sheet that signs in with a Matrix
/// account typed by hand instead of a pairing code (GitHub #4055).
SliverWoltModalSheetPage manualCredentialsPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    // The sheet keeps one name across its entry pages.
    title: context.messages.provisionedSyncImportTitle,
    // No sticky bar, as on the pairing-code page: the one action sits inside
    // the credential frame, under the fields it acts on.
    padding: WoltModalConfig.pagePadding,
    child: ManualCredentialsWidget(pageIndexNotifier: pageIndexNotifier),
  );
}

/// Three fields — server, Matrix ID, password — in one credential frame, and
/// the action that signs in and creates the account's sync room.
///
/// The password is the user's own: it is stored in the device keychain like a
/// bundle's would be, sent only to the server named in the first field, and
/// never rotated — rotation exists to spend a one-time CLI bundle, and there
/// is no bundle here. Submission hands off to
/// `ProvisioningController.configureFromCredentials` and moves the sheet to
/// the connect step, which narrates the rest.
class ManualCredentialsWidget extends ConsumerStatefulWidget {
  const ManualCredentialsWidget({required this.pageIndexNotifier, super.key});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<ManualCredentialsWidget> createState() =>
      _ManualCredentialsWidgetState();
}

class _ManualCredentialsWidgetState
    extends ConsumerState<ManualCredentialsWidget> {
  final _homeServerController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  /// The first field the last submission could not use, or null while every
  /// field is either untried or has been edited since.
  MatrixCredentialsField? _invalidField;

  @override
  void initState() {
    super.initState();
    unawaited(_prefillFromPersistedConfig());
  }

  /// Server and account carry over from a persisted config — the common
  /// reason to be here with one is a password that changed elsewhere, and
  /// retyping the two fields that did not change helps nobody. The password
  /// itself never comes back into a visible field.
  Future<void> _prefillFromPersistedConfig() async {
    final config = await ref.read(matrixServiceProvider).loadConfig();
    if (!mounted || config == null) return;
    if (_homeServerController.text.isEmpty) {
      _homeServerController.text = config.homeServer;
    }
    if (_userController.text.isEmpty) {
      _userController.text = config.user;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _homeServerController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _homeServerController.text.trim().isNotEmpty &&
      _userController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    final input = MatrixCredentialsInput.normalize(
      homeServer: _homeServerController.text,
      user: _userController.text,
      password: _passwordController.text,
    );
    switch (input) {
      case MatrixCredentialsInvalid(:final field):
        setState(() => _invalidField = field);
      case MatrixCredentialsValid(:final config):
        setState(() => _invalidField = null);
        unawaited(
          ref
              .read(provisioningControllerProvider.notifier)
              .configureFromCredentials(config),
        );
        widget.pageIndexNotifier.value = SyncSetupPage.connect;
    }
  }

  void _onChanged(String _) => setState(() => _invalidField = null);

  String? _errorFor(MatrixCredentialsField field) {
    if (_invalidField != field) return null;
    final messages = context.messages;
    return switch (field) {
      MatrixCredentialsField.homeServer =>
        messages.syncCredentialsErrorHomeserver,
      MatrixCredentialsField.user => messages.syncCredentialsErrorUser,
      MatrixCredentialsField.password => messages.syncCredentialsErrorPassword,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.syncCredentialsTitle,
          key: const Key('sync_credentials_title'),
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.syncCredentialsIntro,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        // The credential frame: the same well the pairing-code entry uses, so
        // the two ways in read as one surface. Neutral border rather than the
        // warning one — the paste field holds somebody's live credential that
        // could be a stranger's; these fields hold the user's own.
        SyncWell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignSystemTextInput(
                key: const Key('sync_credentials_homeserver'),
                controller: _homeServerController,
                label: messages.syncCredentialsHomeserverLabel,
                hintText: messages.syncCredentialsHomeserverHint,
                errorText: _errorFor(MatrixCredentialsField.homeServer),
                keyboardType: TextInputType.url,
                autofocus: true,
                onChanged: _onChanged,
              ),
              SizedBox(height: tokens.spacing.step4),
              DesignSystemTextInput(
                key: const Key('sync_credentials_user'),
                controller: _userController,
                label: messages.syncCredentialsUserLabel,
                hintText: messages.syncCredentialsUserHint,
                errorText: _errorFor(MatrixCredentialsField.user),
                keyboardType: TextInputType.emailAddress,
                onChanged: _onChanged,
              ),
              SizedBox(height: tokens.spacing.step4),
              DesignSystemTextInput(
                key: const Key('sync_credentials_password'),
                controller: _passwordController,
                label: messages.syncCredentialsPasswordLabel,
                errorText: _errorFor(MatrixCredentialsField.password),
                obscureText: !_showPassword,
                trailingIcon: _showPassword
                    ? LottiIcons.hidden
                    : LottiIcons.visible,
                trailingIconKey: const Key('sync_credentials_toggle_password'),
                trailingIconTooltip: _showPassword
                    ? messages.syncCredentialsHidePassword
                    : messages.syncCredentialsShowPassword,
                onTrailingIconTap: () =>
                    setState(() => _showPassword = !_showPassword),
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
              ),
              SizedBox(height: tokens.spacing.step4),
              DesignSystemButton(
                key: const Key('sync_credentials_submit'),
                label: messages.syncCredentialsSubmit,
                leadingIcon: LottiIcons.key,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
                // Disabled on an empty field: an empty field can only come
                // back as the validation error the user would see anyway.
                onPressed: _canSubmit ? _submit : null,
              ),
              SizedBox(height: tokens.spacing.step4),
              // Where the password goes, inside the frame that asks for it —
              // the same placement the pairing entry gives its caveat.
              Row(
                key: const Key('sync_credentials_kept_on_device'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LottiIcons.lock,
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      messages.syncCredentialsKeptOnDevice,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        Center(
          child: DesignSystemInlineAction(
            key: const Key('sync_credentials_use_code'),
            onTap: () =>
                widget.pageIndexNotifier.value = SyncSetupPage.pairingCode,
            leadingIcon: LottiIcons.scanQr,
            label: messages.syncCredentialsUsePairingCode,
            semanticsLabel: messages.syncCredentialsUsePairingCode,
          ),
        ),
      ],
    );
  }
}
