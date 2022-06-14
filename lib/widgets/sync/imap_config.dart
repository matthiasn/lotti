import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

import 'imap_config_mobile.dart';

class ImapConfigWidget extends StatelessWidget {
  const ImapConfigWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return const MobileSyncConfig();
    }

    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ImapConfigForm(),
          SizedBox(height: 32),
          ImapConfigActions(),
        ],
      ),
    );
  }
}

class ImapConfigForm extends StatefulWidget {
  const ImapConfigForm({Key? key}) : super(key: key);

  @override
  State<ImapConfigForm> createState() {
    return _ImapConfigFormState();
  }
}

class _ImapConfigFormState extends State<ImapConfigForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      SyncConfigCubit syncConfigCubit = context.read<SyncConfigCubit>();

      void onChanged() {
        syncConfigCubit.setImapConfig(configFromForm(_formKey));
      }

      return FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: onChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            FormBuilderTextField(
              name: 'imap_host',
              initialValue: state.maybeWhen(
                (sharedKey, imapConfig) => imapConfig?.host,
                orElse: () => null,
              ),
              validator: FormBuilderValidators.required(),
              style: inputStyle,
              keyboardAppearance: Brightness.dark,
              decoration: InputDecoration(
                labelText: localizations.settingsSyncHostLabel,
                labelStyle: settingsLabelStyle,
              ),
            ),
            FormBuilderTextField(
              name: 'imap_userName',
              initialValue: state.maybeWhen(
                (sharedKey, imapConfig) => imapConfig?.userName,
                orElse: () => null,
              ),
              validator: FormBuilderValidators.required(),
              style: inputStyle,
              keyboardAppearance: Brightness.dark,
              decoration: InputDecoration(
                labelText: localizations.settingsSyncUserLabel,
                labelStyle: settingsLabelStyle,
              ),
            ),
            FormBuilderTextField(
              name: 'imap_password',
              initialValue: state.maybeWhen(
                (sharedKey, imapConfig) => imapConfig?.password,
                orElse: () => null,
              ),
              obscureText: true,
              validator: FormBuilderValidators.required(),
              style: inputStyle,
              keyboardAppearance: Brightness.dark,
              decoration: InputDecoration(
                labelText: localizations.settingsSyncPasswordLabel,
                labelStyle: settingsLabelStyle,
              ),
            ),
            FormBuilderTextField(
              name: 'imap_port',
              initialValue: state.maybeWhen(
                    (sharedKey, imapConfig) => imapConfig?.port.toString(),
                    orElse: () => null,
                  ) ??
                  '993',
              validator: FormBuilderValidators.integer(),
              style: inputStyle,
              keyboardAppearance: Brightness.dark,
              decoration: InputDecoration(
                labelText: localizations.settingsSyncPortLabel,
                labelStyle: settingsLabelStyle,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class ImapConfigActions extends StatelessWidget {
  const ImapConfigActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      SyncConfigCubit syncConfigCubit = context.read<SyncConfigCubit>();
      return SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            state.when(
              (sharedSecret, imapConfig) => const SizedBox.shrink(),
              configured: (_, __) => Button(
                localizations.settingsSyncDeleteImapButton,
                onPressed: () {
                  syncConfigCubit.deleteImapConfig();
                },
                primaryColor: AppColors.error,
              ),
              imapSaved: (_) => Button(
                localizations.settingsSyncDeleteImapButton,
                onPressed: () {
                  syncConfigCubit.deleteImapConfig();
                },
                primaryColor: AppColors.error,
              ),
              imapValid: (_) => Button(
                localizations.settingsSyncSaveButton,
                primaryColor: Colors.white,
                textColor: AppColors.headerBgColor,
                onPressed: syncConfigCubit.saveImapConfig,
              ),
              imapTesting: (_) => Text(
                'Testing IMAP connection...',
                style: formLabelStyle,
              ),
              imapInvalid: (_, String errorMessage) => Text(
                errorMessage,
                style: formLabelStyle,
              ),
              loading: () => const StatusIndicator(Colors.grey),
              generating: () => const Spacer(),
              empty: () => Text(
                'Please enter valid account details.',
                style: formLabelStyle,
              ),
            ),
            state.when(
              (sharedSecret, imapConfig) => const SizedBox.shrink(),
              configured: (_, __) =>
                  StatusIndicator(AppColors.outboxSuccessColor),
              imapValid: (_) => StatusIndicator(AppColors.outboxSuccessColor),
              imapSaved: (_) => StatusIndicator(AppColors.outboxSuccessColor),
              imapTesting: (_) => StatusIndicator(AppColors.outboxPendingColor),
              imapInvalid: (_, __) => StatusIndicator(AppColors.error),
              loading: () => const StatusIndicator(Colors.grey),
              generating: () => const StatusIndicator(Colors.grey),
              empty: () => const StatusIndicator(Colors.grey),
            ),
          ],
        ),
      );
    });
  }
}

class StatusIndicator extends StatelessWidget {
  const StatusIndicator(
    this.statusColor, {
    Key? key,
  }) : super(key: key);

  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor,
            blurRadius: 8,
            spreadRadius: 2,
          )
        ],
      ),
    );
  }
}
