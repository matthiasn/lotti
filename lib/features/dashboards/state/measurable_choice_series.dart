import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// One calendar day of a choice measurable: the choice recorded last that
/// day, or `null` when nothing was recorded.
typedef ChoiceDay = ({DateTime day, String? choiceId});

/// Reduces a choice measurable's entries to one [ChoiceDay] per calendar day
/// of the range, in order — the shape the day strip renders.
///
/// A day keeps its **latest** recording (by `meta.dateFrom`, then entry id
/// so two replicas agree on equal timestamps): the strip answers "how did
/// the day end up", the way a hydration check is read. Entries without a
/// choice id — numbers recorded before the measurable was switched — do
/// not count as a choice and leave the day empty. The range walk mirrors the
/// numeric aggregators, so a strip and a bar chart of the same window line
/// up cell for bar under the shared date axis.
List<ChoiceDay> choiceDaySeries(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final latestByDay = <String, MeasurementEntry>{};
  for (final entity in entities) {
    if (entity is! MeasurementEntry || entity.data.choiceId == null) continue;
    final key = entity.meta.dateFrom.ymd;
    final current = latestByDay[key];
    if (current == null || _isLater(entity, current)) {
      latestByDay[key] = entity;
    }
  }

  final dayStrings = daysInRange(
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  return [
    for (final dayString in dayStrings)
      (
        day: DateTime.parse(dayString),
        choiceId: latestByDay[dayString]?.data.choiceId,
      ),
  ];
}

bool _isLater(MeasurementEntry a, MeasurementEntry b) {
  final byTime = a.meta.dateFrom.compareTo(b.meta.dateFrom);
  if (byTime != 0) return byTime > 0;
  return a.meta.id.compareTo(b.meta.id) > 0;
}
