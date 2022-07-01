import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/consts.dart';

class ColorsService {
  ColorsService() {
    current = darkTheme;

    _db.watchConfigFlag(showBrightSchemeFlagName).listen((bright) {
      current = bright ? brightTheme : darkTheme;
    });
  }

  late ColorConfig current;
  final _db = getIt<JournalDb>();
}
