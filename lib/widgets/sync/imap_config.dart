import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';

class EmailConfigForm extends StatefulWidget {
  const EmailConfigForm({Key? key}) : super(key: key);

  @override
  State<EmailConfigForm> createState() {
    return _EmailConfigFormState();
  }
}

class _EmailConfigFormState extends State<EmailConfigForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    if (Platform.isIOS || Platform.isAndroid) {
      return BlocBuilder<SyncConfigCubit, SyncConfigState>(
          builder: (context, SyncConfigState state) {
        return Center(
          child: state.maybeWhen(
            (sharedKey, imapConfig) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 88.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Host: ${imapConfig?.host}',
                      style: labelStyleLarger,
                    ),
                    Text(
                      'Port: ${imapConfig?.port}',
                      style: labelStyleLarger,
                    ),
                    Text(
                      'IMAP Folder: ${imapConfig?.folder}',
                      style: labelStyleLarger,
                    ),
                    Text(
                      'User: ${imapConfig?.userName}',
                      style: labelStyleLarger,
                    ),
                    const SizedBox(height: 32),
                    const DeleteSyncConfigButton(),
                  ],
                ),
              );
            },
            orElse: () {
              return null;
            },
          ),
        );
      });
    }

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      return SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: <Widget>[
                  FormBuilderTextField(
                    name: 'imap_host',
                    initialValue: state.maybeWhen(
                      (sharedKey, imapConfig) => imapConfig?.host,
                      orElse: () => null,
                    ),
                    validator: FormBuilderValidators.required(context),
                    style: inputStyle,
                    keyboardAppearance: Brightness.dark,
                    decoration: InputDecoration(
                      labelText: localizations.settingsSyncHostLabel,
                      labelStyle: settingsLabelStyle,
                    ),
                  ),
                  FormBuilderTextField(
                    name: 'imap_folder',
                    initialValue: state.maybeWhen(
                          (sharedKey, imapConfig) => imapConfig?.folder,
                          orElse: () => null,
                        ) ??
                        'INBOX',
                    validator: FormBuilderValidators.required(context),
                    keyboardAppearance: Brightness.dark,
                    style: inputStyle,
                    decoration: InputDecoration(
                      labelText: localizations.settingsSyncFolderLabel,
                      labelStyle: settingsLabelStyle,
                    ),
                  ),
                  FormBuilderTextField(
                    name: 'imap_userName',
                    initialValue: state.maybeWhen(
                      (sharedKey, imapConfig) => imapConfig?.userName,
                      orElse: () => null,
                    ),
                    validator: FormBuilderValidators.required(context),
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
                    validator: FormBuilderValidators.required(context),
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
                          (sharedKey, imapConfig) =>
                              imapConfig?.port.toString(),
                          orElse: () => null,
                        ) ??
                        '993',
                    validator: FormBuilderValidators.integer(context),
                    style: inputStyle,
                    keyboardAppearance: Brightness.dark,
                    decoration: InputDecoration(
                      labelText: localizations.settingsSyncPortLabel,
                      labelStyle: settingsLabelStyle,
                    ),
                  ),
                  Button(
                    localizations.settingsSyncSaveButton,
                    padding: const EdgeInsets.all(24.0),
                    primaryColor: Colors.white,
                    textColor: AppColors.headerBgColor,
                    onPressed: () {
                      _formKey.currentState!.save();
                      if (_formKey.currentState!.validate()) {
                        final formData = _formKey.currentState?.value;
                        ImapConfig cfg = ImapConfig(
                          host: formData!['imap_host'],
                          folder: formData['imap_folder'],
                          userName: formData['imap_userName'],
                          password: formData['imap_password'],
                          port: int.parse(formData['imap_port']),
                        );
                        context.read<SyncConfigCubit>().setImapConfig(cfg);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const DeleteSyncConfigButton(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
