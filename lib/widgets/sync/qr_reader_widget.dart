import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class EncryptionQrReaderWidget extends StatefulWidget {
  const EncryptionQrReaderWidget({super.key});

  @override
  State<StatefulWidget> createState() => _EncryptionQrReaderWidgetState();
}

class _EncryptionQrReaderWidgetState extends State<EncryptionQrReaderWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    Permission.camera.request().then((cameraPermission) {
      debugPrint('cameraPermission $cameraPermission');
    });
  }

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
    final localizations = AppLocalizations.of(context)!;

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

        final camDimension = MediaQuery.of(context).size.width - 100;

        return Center(
          child: state.maybeWhen(
            empty: () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: camDimension,
                    width: camDimension,
                    child: QRView(
                      key: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                    ),
                  ),
                ),
                StatusTextWidget(localizations.settingsSyncScanning),
              ],
            ),
            //  orElse: () => const SizedBox.shrink(),
            orElse: () => const DeleteSyncConfigButton(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
