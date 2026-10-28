import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's local date (midnight), re-emitted when the local day rolls over.
///
/// Due-ness is a function of the date as well as the data: at midnight every
/// task due "today" becomes overdue without a single row changing, so no
/// task notification announces it. Providers whose answer depends on the day
/// — the smart-view counts, the saved-view urgency markers — watch this to
/// recompute then.
///
/// A timer to the next local midnight rather than a periodic tick, so an idle
/// app wakes once a day. A machine asleep across midnight fires it late, on
/// resume, which is exactly when the new day first matters.
final Provider<DateTime> taskDueDayProvider = Provider.autoDispose<DateTime>(
  taskDueDay,
  name: 'taskDueDayProvider',
);
DateTime taskDueDay(Ref ref) {
  final now = clock.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime(now.year, now.month, now.day);
}
