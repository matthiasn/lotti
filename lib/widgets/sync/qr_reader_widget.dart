import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class EncryptionQrReaderWidget extends StatefulWidget {
  const EncryptionQrReaderWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _EncryptionQrReaderWidgetState();
}

class _EncryptionQrReaderWidgetState extends State<EncryptionQrReaderWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      void _onQRViewCreated(QRViewController controller) {
        this.controller = controller;
        controller.scannedDataStream.listen((scanData) {
          if (scanData.code != null) {
            context.read<SyncConfigCubit>().setSyncConfig(scanData.code!);
          }
        });
      }

      return Center(
        child: state.maybeWhen(
            (String? sharedKey, ImapConfig? imapConfig) => TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 32.0,
                      ),
                      backgroundColor: Colors.red),
                  onPressed: () =>
                      context.read<SyncConfigCubit>().deleteSharedKey(),
                  child: Text(
                    localizations.settingsSyncDeleteKeyButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            loading: () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusTextWidget(localizations.settingsSyncLoadingKey),
                    const DeleteSyncConfigButton(),
                  ],
                ),
            generating: () =>
                StatusTextWidget(localizations.settingsSyncGenKey),
            empty: () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 300.0,
                      width: 300.0,
                      child: QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                      ),
                    ),
                    StatusTextWidget(localizations.settingsSyncScanning),
                  ],
                ),
            orElse: () => const SizedBox.shrink()),
      );
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
