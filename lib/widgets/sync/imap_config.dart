import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';

class ImapConfigWidget extends StatefulWidget {
  const ImapConfigWidget({Key? key}) : super(key: key);

  @override
  State<ImapConfigWidget> createState() {
    return _ImapConfigWidgetState();
  }
}

class _ImapConfigWidgetState extends State<ImapConfigWidget> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool validConfig = false;
  bool configError = false;

  ImapConfig? imapConfig;

  @override
  void initState() {
    getImapConfig();
    super.initState();
  }

  Future<void> getImapConfig() async {
    ImapConfig? cfg = await _syncConfigService.getImapConfig();
    setState(() {
      imapConfig = cfg;
    });
    testConnectionWithConfig(cfg);
  }

  void resetStatus() {
    setState(() {
      validConfig = false;
      configError = false;
    });
  }

  ImapConfig? configFromForm() {
    _formKey.currentState!.save();
    if (_formKey.currentState!.validate()) {
      final formData = _formKey.currentState?.value;

      String getTrimmed(String k) {
        return formData![k].toString().trim();
      }

      return ImapConfig(
        host: getTrimmed('imap_host'),
        // folder: getTrimmed('imap_folder'),
        folder: 'INBOX.lotti-sync',
        userName: getTrimmed('imap_userName'),
        password: getTrimmed('imap_password'),
        port: int.parse(formData!['imap_port']),
      );
    } else {
      return null;
    }
  }

  Future<void> testConnectionWithConfig(ImapConfig? cfg) async {
    if (cfg != null) {
      ImapClient? client = await createImapClient(
        SyncConfig(
          imapConfig: cfg,
          sharedSecret: '',
        ),
      );

      if (client != null) {
        setState(() {
          validConfig = true;
        });
      } else {
        setState(() {
          configError = true;
        });
      }
    }
  }

  Future<void> testConnection() async {
    ImapConfig? cfg = configFromForm();
    testConnectionWithConfig(cfg);
  }

  Future<void> saveConfig() async {
    ImapConfig? cfg = configFromForm();
    if (cfg != null) {
      await _syncConfigService.setImapConfig(cfg);
      await getImapConfig();
    }
  }

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
              return const EncryptionQrReaderWidget();
            },
          ),
        );
      });
    }

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      Color statusColor = validConfig
          ? AppColors.outboxSuccessColor
          : configError
              ? AppColors.error
              : Colors.grey;

      return SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: resetStatus,
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
                  // FormBuilderTextField(
                  //   name: 'imap_folder',
                  //   initialValue: state.maybeWhen(
                  //         (sharedKey, imapConfig) => imapConfig?.folder,
                  //         orElse: () => null,
                  //       ) ??
                  //       'INBOX.lotti-sync',
                  //   validator: FormBuilderValidators.required(),
                  //   keyboardAppearance: Brightness.dark,
                  //   style: inputStyle,
                  //   decoration: InputDecoration(
                  //     labelText: localizations.settingsSyncFolderLabel,
                  //     labelStyle: settingsLabelStyle,
                  //   ),
                  // ),
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
                          (sharedKey, imapConfig) =>
                              imapConfig?.port.toString(),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (validConfig && imapConfig == null)
                        Button(
                          localizations.settingsSyncSaveButton,
                          primaryColor: Colors.white,
                          textColor: AppColors.headerBgColor,
                          onPressed: saveConfig,
                        ),
                      if (!validConfig && imapConfig == null)
                        Button(
                          localizations.settingsSyncTestConnectionButton,
                          primaryColor: Colors.white,
                          textColor: AppColors.headerBgColor,
                          onPressed: testConnection,
                        ),
                      if (imapConfig != null)
                        Button(
                          localizations.settingsSyncDeleteImapButton,
                          onPressed: () {
                            _syncConfigService.deleteImapConfig();
                            getImapConfig();
                          },
                          primaryColor: AppColors.error,
                        ),
                      Container(
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
                      )
                    ],
                  ),
                ],
              ),
            ),
            const ImapConfigForm(),
            const SizedBox(height: 32),
            const ImapConfigActions(),
          ],
        ),
      );
    });
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
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          state.when(
            (sharedSecret, imapConfig) => const SizedBox.shrink(),
            configured: (_, __) =>
                StatusIndicator(AppColors.outboxSuccessColor),
            imapValid: (_) => StatusIndicator(AppColors.outboxSuccessColor),
            imapTesting: (_) => StatusIndicator(AppColors.outboxPendingColor),
            imapInvalid: (_, __) => StatusIndicator(AppColors.error),
            loading: () => const StatusIndicator(Colors.grey),
            generating: () => const StatusIndicator(Colors.grey),
            empty: () => const StatusIndicator(Colors.grey),
          ),
        ],
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

ImapConfig? configFromForm(GlobalKey<FormBuilderState> formKey) {
  formKey.currentState!.save();
  if (formKey.currentState!.validate()) {
    final formData = formKey.currentState?.value;

    String getTrimmed(String k) {
      return formData![k].toString().trim();
    }

    return ImapConfig(
      host: getTrimmed('imap_host'),
      // folder: getTrimmed('imap_folder'),
      folder: 'INBOX.lotti-sync',
      userName: getTrimmed('imap_userName'),
      password: getTrimmed('imap_password'),
      port: int.parse(formData!['imap_port']),
    );
  } else {
    return null;
  }
}
