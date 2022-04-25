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

class EmailConfigForm extends StatefulWidget {
  const EmailConfigForm({Key? key}) : super(key: key);

  @override
  _EmailConfigFormState createState() {
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
                padding: const EdgeInsets.all(24),
                child: Column(
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
                      'User: ${imapConfig?.userName}',
                      style: labelStyleLarger,
                    ),
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
        width: 360,
        child: Column(
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
                    validator: FormBuilderValidators.required(context),
                    style: inputStyle,
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
                    ),
                    validator: FormBuilderValidators.integer(context),
                    style: inputStyle,
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
                          userName: formData['imap_userName'],
                          password: formData['imap_password'],
                          port: int.parse(formData['imap_port']),
                        );
                        context.read<SyncConfigCubit>().setImapConfig(cfg);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
