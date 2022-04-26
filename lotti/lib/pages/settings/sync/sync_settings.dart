import 'package:flutter/material.dart';
import 'package:lotti/widgets/sync/imap_config.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({Key? key}) : super(key: key);

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const <Widget>[
          EmailConfigForm(),
          EncryptionQrWidget(),
        ],
      ),
    );
  }
}
