import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return const EncryptionQrReaderWidget();
    }
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Button('Generate Shared Key',
                onPressed: () =>
                    context.read<SyncConfigCubit>().generateSharedKey(),
                primaryColor: Colors.red),
            const Padding(padding: EdgeInsets.all(8.0)),
            state.when(
              (String? sharedKey, ImapConfig? imapConfig) {
                if (sharedKey != null && imapConfig != null) {
                  SyncConfig syncConfig = SyncConfig(
                    imapConfig: imapConfig,
                    sharedSecret: sharedKey,
                  );
                  String syncCfgJson = json.encode(syncConfig);
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
                        child: GestureDetector(
                          onTap: () {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text(
                                  'Copy SyncConfig to Clipboard?',
                                  style: TextStyle(fontFamily: 'Oswald'),
                                ),
                                content: const Text(
                                  'With this data, anyone can read your journal. '
                                  'Only copy when you know what you\'re doing. '
                                  'Are you sure you want to proceed?',
                                  style: TextStyle(fontFamily: 'Lato'),
                                ),
                                actions: <Widget>[
                                  Button(
                                    'Cancel',
                                    onPressed: () {
                                      Navigator.pop(context, 'Cancel');
                                    },
                                    primaryColor: Colors.grey,
                                  ),
                                  Button(
                                    'Copy',
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: syncCfgJson));
                                      Navigator.pop(context, 'Copy SyncConfig');
                                    },
                                    primaryColor: Colors.red,
                                  ),
                                ],
                              ),
                            );
                          },
                          child: QrImage(
                            data: syncCfgJson,
                            version: QrVersions.auto,
                            size: 280.0,
                          ),
                        ),
                      ),
                      StatusTextWidget('${sharedKey.substring(0, 20)}...'),
                      Button('Delete Shared Key',
                          onPressed: () =>
                              context.read<SyncConfigCubit>().deleteSharedKey(),
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
