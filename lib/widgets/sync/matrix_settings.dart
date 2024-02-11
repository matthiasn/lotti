import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/themes/theme.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServerKey = 'home_server';

class MatrixSettingsWidget extends ConsumerStatefulWidget {
  const MatrixSettingsWidget({super.key});

  @override
  ConsumerState<MatrixSettingsWidget> createState() =>
      _MatrixSettingsWidgetState();
}

class _MatrixSettingsWidgetState extends ConsumerState<MatrixSettingsWidget> {
  final _matrixService = getIt<MatrixService>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  MatrixConfig? _previous;

  @override
  void initState() {
    super.initState();
    _matrixService.getMatrixConfig().then((persisted) {
      _previous = persisted;

      if (persisted != null) {
        _formKey.currentState?.patchValue({
          matrixHomeServerKey: persisted.homeServer,
          matrixUserKey: persisted.user,
          matrixPasswordKey: persisted.password,
        });

        setState(() => _dirty = false);
      }
    });
  }

  void onFormChanged() {
    _formKey.currentState?.save();
    setState(() => _dirty = true);
  }

  Future<void> onSavePressed() async {
    final currentState = _formKey.currentState;

    if (currentState == null) {
      return;
    }

    final formData = currentState.value;
    currentState.save();

    if (currentState.validate()) {
      final config = MatrixConfig(
        homeServer: formData[matrixHomeServerKey] as String? ??
            _previous?.homeServer ??
            '',
        user: formData[matrixUserKey] as String? ?? _previous?.user ?? '',
        password:
            formData[matrixPasswordKey] as String? ?? _previous?.password ?? '',
      );

      await _matrixService.setMatrixConfig(config);
      setState(() => _dirty = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    return SingleChildScrollView(
      child: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        onChanged: onFormChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FormBuilderTextField(
              name: matrixHomeServerKey,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixHomeServerLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixUserKey,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixUserLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixPasswordKey,
              obscureText: true,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixPasswordLabel,
                themeData: Theme.of(context),
              ),
            ),
            if (_dirty)
              Center(
                child: TextButton(
                  key: const Key('matrix_config_save'),
                  onPressed: () {
                    onSavePressed();
                    maybePop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      localizations.settingsMeasurableSaveLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Save Matrix Config',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
