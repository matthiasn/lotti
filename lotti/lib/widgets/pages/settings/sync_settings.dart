import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/imap_config.dart';
import 'package:lotti/widgets/sync/imap_status_widget.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sync Settings',
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      backgroundColor: AppColors.entryBgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const <Widget>[
              EmailConfigForm(),
              ImapStatusWidget(),
              EncryptionQrWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
