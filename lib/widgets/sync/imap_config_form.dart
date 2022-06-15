import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

class ImapConfigForm extends StatefulWidget {
  const ImapConfigForm({super.key});

  @override
  State<ImapConfigForm> createState() {
    return _ImapConfigFormState();
  }
}

class _ImapConfigFormState extends State<ImapConfigForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return state.when(
          configured: (cfg, _) => ConfigForm(
            formKey: _formKey,
            imapConfig: cfg,
          ),
          imapSaved: (cfg) => ConfigForm(
            formKey: _formKey,
            imapConfig: cfg,
          ),
          imapValid: (cfg) => ConfigForm(
            formKey: _formKey,
            imapConfig: cfg,
          ),
          imapTesting: (cfg) => ConfigForm(
            formKey: _formKey,
            imapConfig: cfg,
          ),
          imapInvalid: (cfg, _) => ConfigForm(
            formKey: _formKey,
            imapConfig: cfg,
          ),
          loading: () => ConfigForm(formKey: _formKey),
          generating: () => ConfigForm(formKey: _formKey),
          empty: () => ConfigForm(formKey: _formKey),
        );
      },
    );
  }
}

class ConfigForm extends StatelessWidget {
  const ConfigForm({
    super.key,
    required GlobalKey<FormBuilderState> formKey,
    this.imapConfig,
  }) : _formKey = formKey;

  final GlobalKey<FormBuilderState> _formKey;
  final ImapConfig? imapConfig;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final syncConfigCubit = context.read<SyncConfigCubit>();

    void onChanged() {
      syncConfigCubit.setImapConfig(configFromForm(_formKey));
    }

    return FormBuilder(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FormBuilderTextField(
            name: 'imap_host',
            initialValue: imapConfig?.host,
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
            initialValue: imapConfig?.userName,
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
            initialValue: imapConfig?.password,
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
            initialValue: imapConfig?.port.toString() ?? '993',
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
  }
}
