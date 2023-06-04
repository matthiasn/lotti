import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

class ThemesService {
  ThemesService() {
    current = darkTheme;

    if (!isTestEnv) {
      getIt<JournalDb>().watchConfigFlag(showBrightSchemeFlag).listen((bright) {
        darkKeyboard = !bright;
      });
    }
  }

  late StyleConfig current;
  bool darkKeyboard = true;
}
