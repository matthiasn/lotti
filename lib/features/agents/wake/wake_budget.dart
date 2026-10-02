import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/g_counter.dart';

/// The per-agent daily wake budget: how many wakes an agent may run on one
/// calendar day, counted across every device that syncs it.
///
/// The budget is a hard bound on paid inference, independent of whatever
/// triggered the wake. It exists because the trigger side kept growing new
/// paths (subscriptions, fallbacks, restored intents, sync repairs) and one of
/// them could always be wrong — the runaway-wake incident of 2026-10 ran a
/// single project agent several hundred times a day.
///
/// Two limits, deliberately different:
///
/// - [WakeBudgetVerdict.automaticBudgetExhausted]: once `used >= maxPerDay`,
///   automatic wakes stop for the rest of the day.
/// - [WakeBudgetVerdict.hardCeilingReached]: an explicit request ("Update
///   now", creation) still runs past the budget — the user asked for it, and
///   it counts — but not past [hardCeilingFor], twice the budget. The ceiling
///   bounds a request mislabelled as the user's, so no initiator is unbounded.
abstract final class WakeBudget {
  /// Budget for an agent with no stored preference.
  static const defaultMaxWakesPerDay = 10;

  /// The values the agent internals offer. Every stored value is clamped into
  /// `[minMaxWakesPerDay, maxMaxWakesPerDay]` before use, so a peer on another
  /// build cannot lift the bound by writing a larger number.
  static const choices = <int>[1, 2, 3, 5, 10, 15, 20, 24];

  static const minMaxWakesPerDay = 1;
  static const maxMaxWakesPerDay = 24;

  /// Explicit requests may run until this many wakes have been used today.
  static int hardCeilingFor(int maxPerDay) => maxPerDay * 2;
}

/// The effective daily budget of an agent configured with [config].
int effectiveMaxWakesPerDay(AgentConfig config) =>
    (config.maxWakesPerDay ?? WakeBudget.defaultMaxWakesPerDay).clamp(
      WakeBudget.minMaxWakesPerDay,
      WakeBudget.maxMaxWakesPerDay,
    );

/// Whether one more wake may run.
enum WakeBudgetVerdict {
  allowed,

  /// Automatic work is over budget for today; explicit requests still run.
  automaticBudgetExhausted,

  /// Even an explicit request is refused: the hard ceiling is reached.
  hardCeilingReached;

  bool get isAllowed => this == WakeBudgetVerdict.allowed;
}

/// Decides whether a wake started by [initiator] may run when [used] wakes have
/// already run today against a budget of [maxPerDay].
WakeBudgetVerdict evaluateWakeBudget({
  required int used,
  required int maxPerDay,
  required WakeInitiator initiator,
}) {
  if (used >= WakeBudget.hardCeilingFor(maxPerDay)) {
    return WakeBudgetVerdict.hardCeilingReached;
  }
  if (initiator == WakeInitiator.automation && used >= maxPerDay) {
    return WakeBudgetVerdict.automaticBudgetExhausted;
  }
  return WakeBudgetVerdict.allowed;
}

/// The ledger key of [local]'s calendar day, `yyyy-MM-dd`.
///
/// Each device counts against its own local day. Devices in one time zone
/// agree; across zones the day boundary differs by the offset, which can only
/// move a wake into the neighbouring day's count.
String wakeBudgetDay(DateTime local) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}

const _keySeparator = '|';

/// Wakes counted on [day] by every host in [ledger].
///
/// The ledger is a G-counter keyed `<day>|<host>`: each device increments only
/// its own key, so the element-wise-max merge the concurrent resolver applies
/// is the sum of every device's wakes — no increment is lost to a sync race.
int wakesUsedOn(GCounter ledger, String day) {
  final prefix = '$day$_keySeparator';
  var used = 0;
  for (final entry in ledger.byHost.entries) {
    if (entry.key.startsWith(prefix)) used += entry.value;
  }
  return used;
}

/// [ledger] with one wake recorded for [host] on [day], and entries older than
/// the day before [day] dropped.
///
/// Pruning keeps the row small. A peer that still holds a pruned entry can
/// merge it back, which is harmless: only today's entries are ever read, and
/// the next write prunes it again.
GCounter recordWake(
  GCounter ledger, {
  required String day,
  required String host,
}) {
  final retained = <String, int>{
    for (final entry in ledger.byHost.entries)
      if (_dayOf(entry.key).compareTo(_previousDay(day)) >= 0)
        entry.key: entry.value,
  };
  return GCounter(retained).increment('$day$_keySeparator$host');
}

String _dayOf(String key) {
  final index = key.indexOf(_keySeparator);
  return index < 0 ? key : key.substring(0, index);
}

String _previousDay(String day) {
  final parsed = DateTime.tryParse(day);
  if (parsed == null) return day;
  return wakeBudgetDay(
    DateTime(parsed.year, parsed.month, parsed.day - 1),
  );
}
