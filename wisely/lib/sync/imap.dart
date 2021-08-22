import 'dart:io';

import 'package:imap_client/imap_client.dart';
import 'package:yaml/yaml.dart';

class ImapSyncClient {
  late String host;
  late String userName;
  late String password;

  late ImapClient client;

  ImapSyncClient() {
    client = new ImapClient();
    init();
  }

  void init() async {
    final configFile = File('config/mail.yaml');
    final yamlString = await configFile.readAsString();
    final dynamic yamlMap = loadYaml(yamlString);

    host = yamlMap['host'];
    userName = yamlMap['userName'];
    password = yamlMap['password'];

    await client.connect(host, 993, true);
    print(client);
  }
}
