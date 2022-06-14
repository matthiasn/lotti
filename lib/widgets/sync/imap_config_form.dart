import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

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
