import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemesService test -', () {
    setUpAll(() {
      final db = JournalDb(inMemoryDatabase: true);

      getIt.registerSingleton<JournalDb>(db);
    });
    tearDownAll(() async {
      await getIt.reset();
    });
  });
}
