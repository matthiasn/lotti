import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/config_classes.dart';
import 'package:lotti/blocs/sync/encryption_cubit.dart';
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
    return BlocBuilder<EncryptionCubit, EncryptionState>(
        builder: (context, EncryptionState state) {
      void _onQRViewCreated(QRViewController controller) {
        this.controller = controller;
        controller.scannedDataStream.listen((scanData) {
          if (scanData.code != null) {
            context.read<EncryptionCubit>().setSyncConfig(scanData.code!);
          }
        });
      }

      return Center(
        child: state.when(
          (String? sharedKey, ImapConfig? imapConfig) => Column(
            children: [
              StatusTextWidget(sharedKey!),
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 32.0,
                    ),
                    backgroundColor: Colors.red),
                onPressed: () =>
                    context.read<EncryptionCubit>().deleteSharedKey(),
                child: const Text(
                  'Delete Shared Key',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const StatusTextWidget('loading key'),
          generating: () => const StatusTextWidget('generating key'),
          empty: () => Column(
            children: [
              SizedBox(
                height: 300.0,
                width: 300.0,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                ),
              ),
              const StatusTextWidget('Scanning Shared Secret'),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
