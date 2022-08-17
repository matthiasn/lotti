import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/widgets/sync/imap_config_actions.dart';
import 'package:lotti/widgets/sync/imap_config_form.dart';
import 'package:lotti/widgets/sync/imap_config_mobile.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';

class ImapConfigWidget extends StatefulWidget {
  const ImapConfigWidget({super.key});

  @override
  State<ImapConfigWidget> createState() => _ImapConfigWidgetState();
}

class _ImapConfigWidgetState extends State<ImapConfigWidget> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return const MobileSyncConfig();
    }
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ImapConfigForm(),
              const SizedBox(height: 32),
              const ImapConfigStatus(),
              const SizedBox(height: 32),
              const ImapConfigActions(),
              state.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                empty: () => const EmptyConfigWidget(),
              )
            ],
          ),
        );
      },
    );
  }
}
