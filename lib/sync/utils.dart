const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'lastReadUid';

bool validSubject(String subject) {
  final validSubject = RegExp('[a-z0-9]{40}:[a-z0-9]+');
  return validSubject.hasMatch(subject);
}
