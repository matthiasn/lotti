import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

const String hostKey = 'VC_HOST';
const String nextAvailableCounterKey = 'VC_NEXT_AVAILABLE_COUNTER';

const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'LAST_READ_UID';

bool validSubject(String subject) {
  final validSubject = RegExp('[a-z0-9]{40}:[a-z0-9]+');
  return validSubject.hasMatch(subject);
}

Future<void> setLastReadUid(int uid) async {
  await getIt<SettingsDb>().saveSettingsItem(lastReadUidKey, '$uid');
}

Future<int?> getLastReadUid() async {
  final lastReadUidValue = await getIt<SettingsDb>().itemByKey(lastReadUidKey);
  return lastReadUidValue != null ? int.parse(lastReadUidValue) : null;
}
