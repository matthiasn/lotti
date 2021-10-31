import 'package:flutter/material.dart';
import 'package:wisely/widgets/sync/imap_config.dart';
import 'package:wisely/widgets/sync/imap_status_widget.dart';
import 'package:wisely/widgets/sync/qr_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
          ImapStatusWidget(),
          EncryptionQrWidget(),
        ],
      ),
    );
  }
}
