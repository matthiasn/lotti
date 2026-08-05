import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/get_it.dart';

/// Waits for fire-and-forget database work started during registration
/// (EditorStateService.init, the onboarding first-seen write) to finish
/// before databases are closed.
///
/// `pumpEventQueue` cannot see requests in flight on drift's BACKGROUND
/// isolates; closing a database with a pending cross-isolate request
/// completes it with a channel-closed error that fails the test. A probe
/// query on the same connection is FIFO-ordered behind the pending work,
/// so awaiting it guarantees quiescence.
Future<void> settlePendingDbWork() async {
  if (getIt.isRegistered<EditorDb>()) {
    await getIt<EditorDb>().customSelect('SELECT 1').get();
  }
  if (getIt.isRegistered<JournalDb>()) {
    await getIt<JournalDb>().customSelect('SELECT 1').get();
  }
  if (getIt.isRegistered<OnboardingMetricsDb>()) {
    await getIt<OnboardingMetricsDb>().customSelect('SELECT 1').get();
  }
  await pumpEventQueue(times: 100);
}
