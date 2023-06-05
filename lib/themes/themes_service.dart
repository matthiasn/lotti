import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

class ThemesService {
  ThemesService() {
    if (!isTestEnv) {
      getIt<JournalDb>().watchConfigFlag(showBrightSchemeFlag).listen((bright) {
        darkKeyboard = !bright;
      });
    }
  }

  bool darkKeyboard = true;
}
