/// Width-bounded presentation of a sync queue depth.
///
/// The sidebar renders these counts beside the Settings label, in a rail the
/// user can drag down to 200 px. An uncapped integer is what makes that row
/// unresolvable: a queue of 18,342 prints seven glyphs, and every one of them
/// is taken from the label. Bounding the number is therefore not cosmetic —
/// it is what lets Settings and its counts share one row at every width.
library;

import 'package:lotti/l10n/app_localizations.dart';

/// Formats [count] compactly: exact through 999, then thousands.
///
/// One decimal below 10K, because the difference between a queue of 1,200 and
/// one of 9,900 is worth reading; whole thousands above it, where a tenth of a
/// unit is noise on a number the user can only act on in aggregate. A trailing
/// `.0` is always dropped, so 1,000 reads `1K` rather than `1.0K`.
///
/// ```text
///     0 → 0        1000 → 1K       10000 → 10K      1000000 → 1M
///   999 → 999      1200 → 1.2K     18342 → 18K      1234567 → 1.2M
///                  9999 → 10K     999499 → 999K
/// ```
///
/// The unit suffix comes from [messages], not from a literal here: it is
/// visible text, so the catalogs own it and a language that abbreviates
/// thousands differently can say so. Each catalog's entry carries the width
/// constraint in its description, because this string shares one narrow
/// sidebar row with the Settings label.
///
/// Counts originate from `COUNT(*)` and a queue depth, so they are never
/// negative and realistically never reach millions — the `M` step exists so
/// the formatter stays total rather than because a sync queue is expected to
/// get there.
String formatSyncQueueCount(int count, AppLocalizations messages) {
  if (count < 1000) return '$count';
  // Promoted before formatting rather than after: 999,999 thousands rounds to
  // 1000, and `1000K` is not a form this ever wants to print.
  if (count < 999500) {
    return messages.syncQueueCountThousands(_mantissa(count / 1000));
  }
  return messages.syncQueueCountMillions(_mantissa(count / 1000000));
}

/// One decimal below ten, whole numbers from ten up, with a trailing `.0`
/// removed so a whole unit never carries a meaningless fraction.
String _mantissa(double value) {
  final text = value < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Which way a queued item is travelling.
enum SyncQueueDirection {
  /// Waiting to be applied from other devices.
  incoming('↓'),

  /// Waiting to be sent to other devices.
  outgoing('↑');

  const SyncQueueDirection(this.arrow);

  /// The glyph identifying this direction to the reader.
  final String arrow;
}

/// Narrow no-break space (U+202F), between an arrow and its count.
///
/// A word space is too wide here: the arrow is a modifier on the number, not a
/// separate word, and at caption size an ordinary gap makes each count read as
/// two things rather than one. This is a typographic space rather than a
/// spacing token because it must scale with the glyphs it separates — a fixed
/// gap tuned at the default text size is proportionally far tighter once the
/// user raises the system text scale, which is exactly when legibility matters
/// most. No-break rather than a plain thin space so the arrow cannot be parted
/// from its digits if a consumer ever renders this without `maxLines: 1` —
/// today's only one does pin it, so that property is insurance, not the
/// reason.
const syncQueueArrowGap = ' ';

/// The visible label for one direction's queue depth: arrow, narrow
/// no-break space, compacted count.
///
/// Composed here rather than at the call site so the entire visible string has
/// one definition to test and one place to change. The exact figure belongs in
/// the accessible label instead — see [formatSyncQueueCount] for why the
/// visible form is bounded at all.
String formatSyncQueueLabel(
  SyncQueueDirection direction,
  int count,
  AppLocalizations messages,
) {
  return '${direction.arrow}$syncQueueArrowGap'
      '${formatSyncQueueCount(count, messages)}';
}
