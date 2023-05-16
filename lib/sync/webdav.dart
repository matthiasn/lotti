import 'package:flutter/foundation.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:webdav_client/webdav_client.dart';

const String webDavUserKey = 'WEBDAV_USER';
const String webDavPasswordKey = 'WEBDAV_PASSWORD';
const String webDavServerKey = 'WEBDAV_SERVER';

class WebDav {
  WebDav() {
    connect();
  }

  Client? _client;

  Future<void> connect() async {
    debugPrint('WebDAV connect');

    final uri = await getIt<SettingsDb>().itemByKey(webDavServerKey);
    final user = await getIt<SettingsDb>().itemByKey(webDavUserKey);
    final password = await getIt<SettingsDb>().itemByKey(webDavPasswordKey);
    //debugPrint('WebDAV connect $uri $user $password');

    if (uri != null && user != null && password != null) {
      debugPrint('WebDAV connecting $uri $user');

      _client = newClient(
        uri,
        user: user,
        password: password,
        debug: true,
      );
    }
  }

  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    await _client?.writeFromFile(
      localPath,
      remotePath,
      onProgress: (c, t) {
        debugPrint('WebDAV uploadFile onProgress ${c / t}');
      },
    );
  }
}
