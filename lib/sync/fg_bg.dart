import 'dart:async';

import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/platform.dart';

class FgBgService {
  FgBgService() {
    _broadcastStream = _controller.stream.asBroadcastStream();

    if (isMobile) {
      FGBGEvents.stream.listen(
        (result) {
          _controller.add(result != FGBGType.foreground);
        },
        onError: (Object error, Object stacktrace) {
          getIt<LoggingDb>().captureException(
            error,
            stackTrace: stacktrace,
            domain: 'FG_BG',
          );
        },
      );
    }
  }

  final _controller = StreamController<bool>();
  late final Stream<bool> _broadcastStream;

  Stream<bool> get fgBgStream {
    return _broadcastStream;
  }
}
