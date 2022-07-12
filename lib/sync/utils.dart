import 'package:lotti/get_it.dart';
import 'package:lotti/sync/secure_storage.dart';

const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'lastReadUid';

bool validSubject(String subject) {
  final validSubject = RegExp('[a-z0-9]{40}:[a-z0-9]+');
  return validSubject.hasMatch(subject);
}

Future<void> setLastReadUid(int? uid) async {
  await getIt<SecureStorage>().write(key: lastReadUidKey, value: '$uid');
}

Future<int> getLastReadUid() async {
  final lastReadUidValue = await getIt<SecureStorage>().read(
    key: lastReadUidKey,
  );
  return lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;
}
