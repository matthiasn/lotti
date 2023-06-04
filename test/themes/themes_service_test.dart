import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemesService test -', () {
    setUpAll(() {
      final db = JournalDb(inMemoryDatabase: true);

      getIt.registerSingleton<JournalDb>(db);

      db.insertFlagIfNotExists(
        const ConfigFlag(
          name: showBrightSchemeFlag,
          description: 'Show Bright ☀️ scheme?',
          status: false,
        ),
      );
    });
    tearDownAll(() async {
      await getIt.reset();
    });
  });
}
