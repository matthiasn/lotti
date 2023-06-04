import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';

class MobileSyncConfig extends StatelessWidget {
  const MobileSyncConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return Center(
          child: state.maybeWhen(
            configured: (imapConfig, sharedKey) {
              return ImapConfigInfo(imapConfig: imapConfig);
            },
            imapInvalid: (imapConfig, sharedKey) {
              return ImapConfigInfo(imapConfig: imapConfig);
            },
            orElse: () {
              return const EncryptionQrReaderWidget();
            },
          ),
        );
      },
    );
  }
}

class ImapConfigInfo extends StatelessWidget {
  const ImapConfigInfo({
    required this.imapConfig,
    super.key,
  });

  final ImapConfig imapConfig;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Host: ${imapConfig.host}'),
          Text('Port: ${imapConfig.port}'),
          Text('IMAP Folder: ${imapConfig.folder}'),
          Text('User: ${imapConfig.userName}'),
          const SizedBox(height: 32),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeleteSyncConfigButton(),
              SizedBox(width: 16),
              ImapConfigStatus(
                showText: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
