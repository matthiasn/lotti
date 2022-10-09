import 'dart:math';

import 'package:lotti/utils/platform.dart';

void runSoon({
  required int minWait,
  required int maxWait,
  required void Function() callback,
}) {
  if (isTestEnv) {
    callback();
  } else {
    final random = Random();
    final randomMs = random.nextInt(maxWait - minWait);
    Future.delayed(Duration(milliseconds: minWait + randomMs), callback);
  }
}
