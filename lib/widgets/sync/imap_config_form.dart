import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

class ImapConfigForm extends StatefulWidget {
  const ImapConfigForm({
    super.key,
    this.formKey,
  });

  @override
  State<ImapConfigForm> createState() {
    return _ImapConfigFormState();
  }

  final GlobalKey<FormBuilderState>? formKey;
}

class _ImapConfigFormState extends State<ImapConfigForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final formKey = widget.formKey ?? _formKey;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return SizedBox(
          height: 300,
          child: state.when(
            configured: (cfg, _) => ConfigForm(
              formKey: formKey,
              imapConfig: cfg,
            ),
            imapSaved: (cfg) => ConfigForm(
              formKey: formKey,
              imapConfig: cfg,
            ),
            imapValid: (cfg) => ConfigForm(
              formKey: formKey,
              imapConfig: cfg,
            ),
            imapTesting: (cfg) => ConfigForm(
              formKey: formKey,
              imapConfig: cfg,
            ),
            imapInvalid: (cfg, _) => ConfigForm(
              formKey: formKey,
              imapConfig: cfg,
            ),
            loading: () => const SizedBox.shrink(),
            generating: () => ConfigForm(formKey: formKey),
            empty: () => ConfigForm(formKey: formKey),
          ),
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
            key: const Key('imap_host_form_field'),
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
            key: const Key('imap_user_name_form_field'),
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
            key: const Key('imap_password_form_field'),
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
            key: const Key('imap_port_form_field'),
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
