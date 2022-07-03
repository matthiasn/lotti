import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/consts.dart';

class ColorsService {
  ColorsService({bool watch = true}) {
    current = darkTheme;

    if (watch) {
      _controller = StreamController<ColorConfig>.broadcast();
      getIt<JournalDb>()
          .watchConfigFlag(showBrightSchemeFlagName)
          .listen((bright) {
        current = bright ? brightTheme : darkTheme;
        _controller.add(current);
        getIt<NavService>().restoreRoute();
      });
    }
  }

  late ColorConfig current;
  late final StreamController<ColorConfig> _controller;

  Stream<ColorConfig> getStream() {
    return _controller.stream;
  }

  void setTheme(ColorConfig updated) {
    current = updated;
    _controller.add(current);
  }
}
