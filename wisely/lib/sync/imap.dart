import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/sync/secure_storage.dart';

import 'encryption_salsa.dart';

class ImapSyncClient {
  late ImapConfig _imapConfig;
  late ImapClient client;

  ImapSyncClient(ImapConfig imapConfig) {
    client = ImapClient(isLogEnabled: true);
    _imapConfig = imapConfig;
    init();
    listen();
  }

  void init() async {
    print('host: ${_imapConfig.host}.host, user: ${_imapConfig.userName}');

    await client.connectToServer(_imapConfig.host, _imapConfig.port,
        isSecure: true);
    await client.login(_imapConfig.userName, _imapConfig.password);

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
    print('host: ${_imapConfig.host}.host, user: ${_imapConfig.userName}');

    final account = MailAccount.fromManualSettings(
      'sync',
      _imapConfig.userName,
      _imapConfig.host,
      _imapConfig.host,
      _imapConfig.password,
    );

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
      mailClient.eventBus.on<MailLoadEvent>().listen((event) async {
        print('New message at ${DateTime.now()}:');

        if (event.message.uid != null) {
          try {
            FetchImapResult res =
                await client.uidFetchMessage(event.message.uid!, 'BODY.PEEK[]');
            for (final msg in res.messages) {
              printMessage(msg);
            }
          } on MailException catch (e) {
            print('High level API failed with $e');
          }
        }
      });
      await mailClient.startPolling();
    } on MailException catch (e) {
      print('High level API failed with $e');
    }
  }

  void printDecryptedMessage(String encryptedMessage) async {
    print('printDecryptedMessage: $encryptedMessage');
    String? b64Secret = await SecureStorage.readValue('sharedSecret');
    if (b64Secret != null) {
      String json = decryptSalsa(encryptedMessage, b64Secret);
      print('Decrypted from IMAP: $json');
    }
  }

  void printMessage(MimeMessage message) {
    print(
        'from: ${message.from} with subject "${message.decodeSubject()}" and sequenceId ${message.sequenceId} and uid ${message.uid}');
    if (!message.isTextPlainMessage()) {
      print(' content-type: ${message.mediaType}');
    } else {
      final plainText = message.decodeTextPlainPart();
      String concatenated = '';
      if (plainText != null) {
        final lines = plainText.split('\r\n');
        for (final line in lines) {
          if (line.startsWith('>')) {
            break;
          }
          concatenated = concatenated + line;
        }
        String encrypted = concatenated.trim();
        printDecryptedMessage(encrypted);
      }
    }
  }

  void saveImapMessage(String subject, String encryptedMessage) async {
    Mailbox inbox = await client.selectInbox();
    final builder = MessageBuilder.prepareMultipartAlternativeMessage();
    builder.from = [MailAddress('Sync', 'sender@domain.com')];
    builder.to = [MailAddress('Sync', 'recipient@domain.com')];
    builder.subject = subject;
    builder.addTextPlain(encryptedMessage);
    final MimeMessage message = builder.buildMimeMessage();
    client.appendMessage(message, targetMailbox: inbox);
  }
}
