import 'package:lotti/classes/config.dart';

const defaultWait = Duration(milliseconds: 100);

const testSharedKey = 'abc123';

const testImapConfig = ImapConfig(
  host: 'mail.foo.com',
  folder: 'folder',
  userName: 'userName',
  password: 'password',
  port: 993,
);

const testSyncConfigNoKey = SyncConfig(
  imapConfig: testImapConfig,
  sharedSecret: '',
);

const testSyncConfigConfigured = SyncConfig(
  imapConfig: testImapConfig,
  sharedSecret: testSharedKey,
);

final testSyncConfigJson = testSyncConfigConfigured.toJson().toString();
