import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServer = 'home_server';

class MatrixSettingsWidget extends ConsumerStatefulWidget {
  const MatrixSettingsWidget({super.key});

  @override
  ConsumerState<MatrixSettingsWidget> createState() =>
      _MatrixSettingsWidgetState();
}

class _MatrixSettingsWidgetState extends ConsumerState<MatrixSettingsWidget> {
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
              initialValue: config?.homeServer,
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixSyncHomeServerLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixUserKey,
              initialValue: config?.user,
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixSyncUserLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixPasswordKey,
              initialValue: config?.password,
              obscureText: true,
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
