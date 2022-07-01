import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/consts.dart';

class ColorsService {
  ColorsService({bool watch = true}) {
    current = darkTheme;

    if (watch) {
      getIt<JournalDb>()
          .watchConfigFlag(showBrightSchemeFlagName)
          .listen((bright) {
        current = bright ? brightTheme : darkTheme;
      });
    }
  }

  late ColorConfig current;
}
