import 'package:lotti/classes/config.dart';

const defaultWait = Duration(milliseconds: 100);

const testSharedKey = 'abc123';

final testImapConfig = ImapConfig(
  host: 'host',
  folder: 'folder',
  userName: 'userName',
  password: 'password',
  port: 993,
);

final testSyncConfigNoKey = SyncConfig(
  imapConfig: testImapConfig,
  sharedSecret: '',
);

final testSyncConfigConfigured = SyncConfig(
  imapConfig: testImapConfig,
  sharedSecret: testSharedKey,
);

final testSyncConfigJson = testSyncConfigConfigured.toJson().toString();
