import 'package:dio/dio.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/sync/secure_storage.dart';

const String secretKey = 'SPOTIFY_SECRET';

class SpotifyImport {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final JournalDb _db = getIt<JournalDb>();
  final Dio dio = Dio();

  SpotifyImport() : super();

  Future<void> setNewSecret() async {
    SecureStorage.writeValue(secretKey, 'REPLACE_ME');
  }

  Future<String> getSecret() async {
    String? secret = await SecureStorage.readValue(secretKey);
    if (secret == null) {
      setNewSecret();
    }

    return secret ?? '';
  }

  Future<void> importRecentlyPlayed() async {
    Map<String, dynamic> map = Map<String, dynamic>();
    map['grant_type'] = 'password';

    FormData formData = FormData.fromMap(map);

    try {
      String url = 'https://accounts.spotify.com/api/token';
      Response response = await dio.post(url, data: formData);
      print(response);
    } catch (e) {
      print(e);
    }
  }
}
