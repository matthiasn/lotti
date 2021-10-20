import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/widgets/sync/qr_reader_widget.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return EncryptionQrReaderWidget();
    }
    return BlocBuilder<EncryptionCubit, EncryptionState>(
        builder: (context, EncryptionState state) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 32.0,
                  ),
                  backgroundColor: Colors.red),
              onPressed: () =>
                  context.read<EncryptionCubit>().generateSharedKey(),
              child: const Text(
                'Generate Shared Key',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
