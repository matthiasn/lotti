import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServer = 'home_server';

class MatrixSettings extends ConsumerStatefulWidget {
  const MatrixSettings({super.key});

  @override
  ConsumerState<MatrixSettings> createState() => _MatrixSettingsState();
}

class _MatrixSettingsState extends ConsumerState<MatrixSettings> {
  final _formKey = GlobalKey<FormBuilderState>();
  MatrixConfig? config;

  void onChanged() {
    final config = matrixConfigFromForm(_formKey);
    debugPrint('config $config');
  }

  @override
  void initState() {
    super.initState();

    getIt<MatrixService>().getMatrixConfig().then((value) {
      setState(() {
        config = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: onChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FormBuilderTextField(
              name: matrixHomeServer,
              key: const Key('matrix_home_server_form_field'),
              initialValue: config?.homeServer,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixSyncHomeServerLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixUserKey,
              key: const Key('matrix_user_form_field'),
              initialValue: config?.user,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixSyncUserLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixPasswordKey,
              key: const Key('matrix_password_form_field'),
              initialValue: config?.password,
              obscureText: true,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixSyncPasswordLabel,
                themeData: Theme.of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

MatrixConfig? matrixConfigFromForm(GlobalKey<FormBuilderState> formKey) {
  formKey.currentState!.save();
  if (formKey.currentState!.validate()) {
    final formData = formKey.currentState?.value;

    return MatrixConfig(
      homeServer: getTrimmed(formData, 'home_server'),
      user: getTrimmed(formData, matrixUserKey),
      password: getTrimmed(formData, matrixPasswordKey),
    );
  } else {
    return null;
  }
}
