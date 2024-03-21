import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/sync/matrix/incoming_stats.dart';
import 'package:lotti/widgets/sync/matrix/unverified_devices.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServerKey = 'home_server';
const matrixRoomIdKey = 'room_id';

class MatrixSettingsWidget extends ConsumerStatefulWidget {
  const MatrixSettingsWidget({super.key});

  @override
  ConsumerState<MatrixSettingsWidget> createState() =>
      _MatrixSettingsWidgetState();
}

class _MatrixSettingsWidgetState extends ConsumerState<MatrixSettingsWidget> {
  final _matrixService = getIt<MatrixService>();
  final _formKey = GlobalKey<FormBuilderState>();
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'matrix_QR_key');

  bool _dirty = false;
  MatrixConfig? _previous;
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _matrixService.loadMatrixConfig().then((persisted) {
      _previous = persisted;

      if (persisted != null) {
        _formKey.currentState?.patchValue({
          matrixHomeServerKey: persisted.homeServer,
          matrixUserKey: persisted.user,
          matrixPasswordKey: persisted.password,
          matrixRoomIdKey: persisted.roomId,
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
        roomId: formData[matrixRoomIdKey] as String? ?? _previous?.roomId ?? '',
      );

      await _matrixService.setMatrixConfig(config);
      setState(() => _dirty = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    final camDimension =
        max(MediaQuery.of(context).size.width - 100, 300).toDouble();

    void onQRViewCreated(QRViewController controller) {
      this.controller = controller;
      controller.scannedDataStream.listen((scanData) async {
        final jsonString = scanData.code;
        if (jsonString != null) {
          final parsed = json.decode(jsonString) as Map<String, dynamic>;
          final scannedConfig = MatrixConfig.fromJson(parsed);
          await _matrixService.setMatrixConfig(scannedConfig);
          maybePop();
        }
      });
    }

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
            const SizedBox(height: 20),
            FormBuilderTextField(
              name: matrixRoomIdKey,
              validator: FormBuilderValidators.required(),
              decoration: inputDecoration(
                labelText: localizations.settingsMatrixRoomIdLabel,
                themeData: Theme.of(context),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_previous != null)
                  OutlinedButton(
                    key: const Key('matrix_config_delete'),
                    onPressed: () async {
                      await _matrixService.logout();
                      await _matrixService.deleteMatrixConfig();
                      setState(() {
                        _dirty = false;
                      });
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixDeleteLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      semanticsLabel: 'Delete Matrix Config',
                    ),
                  ),
                if (_dirty)
                  OutlinedButton(
                    key: const Key('matrix_config_save'),
                    onPressed: () {
                      onSavePressed();
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixSaveLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      semanticsLabel: 'Save Matrix Config',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            if (_previous != null && !_dirty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: jsonEncode(_previous),
                      padding: EdgeInsets.zero,
                      size: 280,
                      key: const Key('QrImage'),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            Text('Device ID: ${_matrixService.getDeviceId()}'),
            Text('Device Name: ${_matrixService.getDeviceName()}'),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_matrixService.isLoggedIn())
                  OutlinedButton(
                    key: const Key('matrix_logout'),
                    onPressed: () {
                      _matrixService.logout();
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixLogoutButtonLabel,
                      semanticsLabel:
                          localizations.settingsMatrixLogoutButtonLabel,
                    ),
                  )
                else
                  OutlinedButton(
                    key: const Key('matrix_login'),
                    onPressed: () {
                      _matrixService.loginAndListen();
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixLoginButtonLabel,
                      semanticsLabel:
                          localizations.settingsMatrixLoginButtonLabel,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            if (isMobile && _previous == null && !_dirty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: camDimension,
                  width: camDimension,
                  child: QRView(
                    key: _qrKey,
                    onQRViewCreated: onQRViewCreated,
                  ),
                ),
              ),
            if (_matrixService.isLoggedIn()) const UnverifiedDevices(),
            const SizedBox(height: 40),
            const IncomingStats(),
            OutlinedButton(
              key: const Key('matrix_create_room'),
              onPressed: () async {
                await _matrixService.createRoom();
              },
              child: const Text('Create room'),
            ),
          ],
        ),
      ),
    );
  }
}
