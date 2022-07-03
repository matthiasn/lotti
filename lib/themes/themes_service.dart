import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/consts.dart';

class ColorsService {
  ColorsService({bool watch = true}) {
    current = darkTheme;

    if (watch) {
      _controller = StreamController<ColorConfig>.broadcast();
      _updateController = StreamController<DateTime>.broadcast();
      getIt<JournalDb>()
          .watchConfigFlag(showBrightSchemeFlagName)
          .listen((bright) {
        current = bright ? brightTheme : darkTheme;
        _controller.add(current);
        _updateController.add(DateTime.now());
      });
    }
  }

  late ColorConfig current;
  late final StreamController<ColorConfig> _controller;
  late final StreamController<DateTime> _updateController;

  Stream<ColorConfig> getColorConfigStream() {
    return _controller.stream;
  }

  Stream<DateTime> getLastUpdateStream() {
    return _updateController.stream;
  }

  void setTheme(ColorConfig updated) {
    current = updated;
    _controller.add(current);
    _updateController.add(DateTime.now());
  }
}
