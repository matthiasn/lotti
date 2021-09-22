import 'package:flutter/services.dart';
// import 'package:imap_client/imap_client.dart';
import 'package:yaml/yaml.dart';

class ImapSyncClient {
  late String host;
  late String userName;
  late String password;

//  late ImapClient client;

  ImapSyncClient() {
//    client = new ImapClient();
    init();
  }

  void init() async {
    String yamlString = await rootBundle.loadString('assets/config/mail.yaml');
    final dynamic yamlMap = loadYaml(yamlString);

    host = yamlMap['host'];
    userName = yamlMap['userName'];
    password = yamlMap['password'];

    // await client.connect(host, 993, true);
    // await client.login(userName, password);
    // client.capability().then((value) => print(value));
    // print(client);
    //
    // ImapFolder inbox = await client.getFolder('Inbox');
    // print(inbox);
    //
    // List<int> emails = await inbox.search('UNSEEN');
    // print(emails);
    // int emails1 = await inbox.mailCount;
    // print(emails1);
  }
}
