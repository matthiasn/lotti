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
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
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
    _matrixService.getMatrixConfig().then((persisted) {
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
                  TextButton(
                    key: const Key('matrix_config_delete'),
                    onPressed: () async {
                      await _matrixService.deleteMatrixConfig();
                      setState(() {
                        _dirty = false;
                      });
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixDeleteLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Delete Matrix Config',
                    ),
                  ),
                if (_dirty)
                  TextButton(
                    key: const Key('matrix_config_save'),
                    onPressed: () {
                      onSavePressed();
                      maybePop();
                    },
                    child: Text(
                      localizations.settingsMatrixSaveLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Save Matrix Config',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            if (_previous != null && !_dirty)
              Center(
                child: ColoredBox(
                  color: Colors.white,
                  child: QrImageView(
                    data: jsonEncode(_previous),
                    size: 280,
                    key: const Key('QrImage'),
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
          ],
        ),
      ),
    );
  }
}

class UnverifiedDevices extends StatefulWidget {
  const UnverifiedDevices({super.key});

  @override
  State<UnverifiedDevices> createState() => _UnverifiedDevicesState();
}

class _UnverifiedDevicesState extends State<UnverifiedDevices> {
  final _matrixService = getIt<MatrixService>();
  List<DeviceKeys> _unverifiedDevices = [];

  @override
  void initState() {
    super.initState();
    setState(() {
      _unverifiedDevices = _matrixService.getUnverified();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (_unverifiedDevices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(localizations.settingsMatrixNoUnverifiedLabel),
          const StatusIndicator(
            Colors.greenAccent,
            semanticsLabel: 'No unverified devices',
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations.settingsMatrixListUnverifiedLabel,
              semanticsLabel: localizations.settingsMatrixListUnverifiedLabel,
            ),
            IconButton(
              key: const Key('matrix_list_unverified'),
              onPressed: () {
                setState(() {
                  _unverifiedDevices = _matrixService.getUnverified();
                });
              },
              icon: Icon(MdiIcons.refresh),
            ),
          ],
        ),
        ..._unverifiedDevices.map(DeviceCard.new),
      ],
    );
  }
}

class DeviceCard extends StatefulWidget {
  const DeviceCard(
    this.deviceKeys, {
    super.key,
  });

  final DeviceKeys deviceKeys;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  final _matrixService = getIt<MatrixService>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Card(
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.deviceKeys.deviceDisplayName ??
                  widget.deviceKeys.deviceId ??
                  '',
            ),
            IconButton(
              padding: const EdgeInsets.all(10),
              icon: Semantics(
                label: 'Delete device',
                child: Icon(MdiIcons.trashCanOutline),
              ),
              onPressed: () => _matrixService.deleteDevice(widget.deviceKeys),
            ),
          ],
        ),
        subtitle: Column(
          children: [
            Text(widget.deviceKeys.userId),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return VerificationModal(widget.deviceKeys);
                  },
                );
              },
              child: Text(
                localizations.settingsMatrixVerifyLabel,
                semanticsLabel: localizations.settingsMatrixVerifyLabel,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

enum VerificationStep {
  initial,
  started,
  continued,
  accepted,
  emojisReceived,
}

class VerificationModal extends StatefulWidget {
  const VerificationModal(
    this.deviceKeys, {
    super.key,
  });

  final DeviceKeys deviceKeys;

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal> {
  final _matrixService = getIt<MatrixService>();
  List<KeyVerificationEmoji>? _emojis;
  VerificationStep _verificationStep = VerificationStep.initial;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    void closeModal() {
      Navigator.of(context).pop();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.deviceKeys.deviceDisplayName ??
                      widget.deviceKeys.deviceId ??
                      '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: 0.5,
              child: Text(
                widget.deviceKeys.userId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            if (_verificationStep == VerificationStep.initial)
              OutlinedButton(
                key: const Key('matrix_start_verify'),
                onPressed: () async {
                  await _matrixService.verifyDevice(widget.deviceKeys);
                  setState(() {
                    _verificationStep = VerificationStep.started;
                  });
                },
                child: Text(
                  localizations.settingsMatrixStartVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixStartVerificationLabel,
                ),
              ),
            if (_verificationStep == VerificationStep.started)
              OutlinedButton(
                key: const Key('matrix_continue_verify'),
                onPressed: () async {
                  await _matrixService.continueVerification();
                  setState(() {
                    _verificationStep = VerificationStep.continued;
                  });
                },
                child: const Text(
                  'continue',
                ),
              ),
            if (_verificationStep == VerificationStep.continued)
              OutlinedButton(
                key: const Key('matrix_accept_verify'),
                onPressed: () async {
                  final emojis = await _matrixService.acceptEmojiVerification();
                  setState(() {
                    _emojis = emojis;
                    _verificationStep = VerificationStep.emojisReceived;
                  });
                },
                child: Text(
                  localizations.settingsMatrixAcceptVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixAcceptVerificationLabel,
                ),
              ),
            if (_emojis != null &&
                _verificationStep == VerificationStep.emojisReceived) ...[
              Text(
                localizations.settingsMatrixVerifyConfirm,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              VerificationEmojisRow(_emojis?.take(4)),
              VerificationEmojisRow(_emojis?.skip(4)),
              const SizedBox(height: 20),
              OutlinedButton(
                key: const Key('matrix_cancel_verification'),
                onPressed: () async {
                  await _matrixService.cancelVerification();
                  closeModal();
                },
                child: Text(
                  localizations.settingsMatrixCancelVerificationLabel,
                  semanticsLabel:
                      localizations.settingsMatrixCancelVerificationLabel,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class VerificationEmojisRow extends StatelessWidget {
  const VerificationEmojisRow(
    this.emojis, {
    super.key,
  });

  final Iterable<KeyVerificationEmoji>? emojis;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...?emojis?.map(
          (emoji) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: Column(
              children: [
                Text(
                  emoji.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
                Text(
                  emoji.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
