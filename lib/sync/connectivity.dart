import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';

class ConnectivityService {
  ConnectivityService() {
    _broadcastStream = _controller.stream.asBroadcastStream();

    Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        debugPrint('Connectivity onConnectivityChanged $result');
        getIt<LoggingDb>().captureEvent(
          'onConnectivityChanged $result',
          domain: 'CONNECTIVITY',
        );
        _controller.add(result != ConnectivityResult.none);
      },
      onError: (Object error, Object stacktrace) {
        getIt<LoggingDb>().captureException(
          error,
          stackTrace: stacktrace,
          domain: 'CONNECTIVITY',
        );
      },
    );
  }

  final _controller = StreamController<bool>();
  late final Stream<bool> _broadcastStream;

  Future<bool> isConnected() async {
    final status = await Connectivity().checkConnectivity();
    return status != ConnectivityResult.none;
  }

  Stream<bool> get connectedStream {
    return _broadcastStream;
  }
}
