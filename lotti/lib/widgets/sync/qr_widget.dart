import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/config_classes.dart';
import 'package:lotti/blocs/sync/encryption_cubit.dart';
import 'package:lotti/widgets/buttons.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return const EncryptionQrReaderWidget();
    }
    return BlocBuilder<EncryptionCubit, EncryptionState>(
        builder: (context, EncryptionState state) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Button('Generate Shared Key',
                onPressed: () =>
                    context.read<EncryptionCubit>().generateSharedKey(),
                primaryColor: Colors.red),
            const Padding(padding: EdgeInsets.all(8.0)),
            state.when(
              (String? sharedKey, ImapConfig? imapConfig) {
                if (sharedKey != null && imapConfig != null) {
                  SyncConfig syncConfig = SyncConfig(
                      imapConfig: imapConfig, sharedSecret: sharedKey);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(8.0),
                          ),
                        ),
                        child: QrImage(
                          data: json.encode(syncConfig),
                          version: QrVersions.auto,
                          size: 280.0,
                        ),
                      ),
                      StatusTextWidget(sharedKey),
                      Button('Delete Shared Key',
                          onPressed: () =>
                              context.read<EncryptionCubit>().deleteSharedKey(),
                          primaryColor: Colors.red),
                    ],
                  );
                } else {
                  return const StatusTextWidget('incomplete config');
                }
              },
              loading: () => const StatusTextWidget('loading key'),
              generating: () => const StatusTextWidget('generating key'),
              empty: () => const StatusTextWidget('not initialized'),
            ),
          ],
        ),
      );
    });
  }
}

class StatusTextWidget extends StatelessWidget {
  final String label;
  const StatusTextWidget(
    this.label, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'ShareTechMono',
        ),
      ),
    );
  }
}
