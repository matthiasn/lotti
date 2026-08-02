import 'package:lotti/database/slow_query_logging.dart';

/// Restores the public slow-query gate flags without exposing test-only
/// mutation APIs from production code.
void resetSlowQueryLoggingGate() {
  SlowQueryLoggingGate.isEnabled = false;
  SlowQueryLoggingGate.captureFirstCallStack = false;
}
