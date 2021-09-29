import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ImapSyncClient {
  late String host;
  late String userName;
  late String password;

  late ImapClient client;

  ImapSyncClient() {
    client = ImapClient(isLogEnabled: true);
    init();
    listen();
  }

  void init() async {
    String yamlString = await rootBundle.loadString('assets/config/mail.yaml');
    final dynamic yamlMap = loadYaml(yamlString);

    host = yamlMap['host'];
    userName = yamlMap['userName'];
    password = yamlMap['password'];
    const imapServerPort = 993;

    print('host: $host, user: $userName');

    await client.connectToServer(host, imapServerPort, isSecure: true);
    await client.login(userName, password);

    final mailboxes = await client.listMailboxes();
    print('mailboxes: $mailboxes');
    await client.selectInbox();

    // fetch 10 most recent messages:
    final fetchResult = await client.fetchRecentMessages(
        messageCount: 10, criteria: 'BODY.PEEK[]');

    for (final message in fetchResult.messages) {
      printMessage(message);
    }
  }

  void listen() async {
    String yamlString = await rootBundle.loadString('assets/config/mail.yaml');
    final dynamic yamlMap = loadYaml(yamlString);

    host = yamlMap['host'];
    userName = yamlMap['userName'];
    password = yamlMap['password'];
    const imapServerPort = 993;

    print('host: $host, user: $userName');

    final account =
        MailAccount.fromManualSettings('sync', userName, host, host, password);

    final mailClient = MailClient(account, isLogEnabled: true);

    try {
      await mailClient.connect();
      print('connected');
      final mailboxes =
          await mailClient.listMailboxesAsTree(createIntermediate: false);
      print(mailboxes);
      await mailClient.selectInbox();
      final messages = await mailClient.fetchMessages(count: 20);
      for (final msg in messages) {
        printMessage(msg);
      }
      mailClient.eventBus.on<MailLoadEvent>().listen((event) {
        print('New message at ${DateTime.now()}:');
        printMessage(event.message);
      });
      await mailClient.startPolling();
    } on MailException catch (e) {
      print('High level API failed with $e');
    }
  }

  void printMessage(MimeMessage message) {
    print('from: ${message.from} with subject "${message.decodeSubject()}"');
    if (!message.isTextPlainMessage()) {
      print(' content-type: ${message.mediaType}');
    } else {
      final plainText = message.decodeTextPlainPart();
      if (plainText != null) {
        final lines = plainText.split('\r\n');
        for (final line in lines) {
          if (line.startsWith('>')) {
            break;
          }
          print(line);
        }
      }
    }
  }
}
