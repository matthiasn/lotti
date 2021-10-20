import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/widgets/sync/qr_widget.dart';

class EncryptionQrReaderWidget extends StatefulWidget {
  const EncryptionQrReaderWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _EncryptionQrReaderWidgetState();
}

class _EncryptionQrReaderWidgetState extends State<EncryptionQrReaderWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late QRViewController controller;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller.pauseCamera();
    } else if (Platform.isIOS) {
      controller.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EncryptionCubit, EncryptionState>(
        builder: (context, EncryptionState state) {
      void _onQRViewCreated(QRViewController controller) {
        this.controller = controller;
        controller.scannedDataStream.listen((scanData) {
          context.read<EncryptionCubit>().setSharedKey(scanData.code);
        });
      }

      return Center(
        child: state.when(
          (String? sharedKey) => Column(
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
    controller.dispose();
    super.dispose();
  }
}
