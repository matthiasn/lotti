part of 'agent_domain_entity.dart';

/// Applies compatibility repairs and domain validation around Freezed's
/// generated union decoder.
///
/// The public factory must stay expression-bodied: Freezed uses that shape to
/// decide whether it should generate JSON support for the union variants.
AgentDomainEntity _decodeAgentDomainEntity(Map<String, dynamic> json) {
  // The stub check reads the raw keys, so it runs before anything adds or
  // demands one: the weekRollup repair derives `weekStart` from a stub's
  // canonical id, which made the stub look like a real payload, and the
  // goal-spec validation rejects a stub for the `version` it never had.
  if (_isUnknownFallbackRoundTrip(json)) {
    return AgentUnknownEntity.fromJson(json);
  }
  final repaired = _repairLegacyWeekRollup(json);
  _validateGoalSpecJson(repaired);
  _validateNudgeJson(repaired);
  final entity = _$AgentDomainEntityFromJson(repaired);
  if (entity is GoalSpecVersionEntity) {
    final issues = GoalSpecValidator.criterionIssues(entity.criteria);
    if (issues.isNotEmpty) {
      throw FormatException('Invalid goal criteria: ${issues.join('; ')}');
    }
  }
  return entity;
}

/// Exactly the keys an [AgentUnknownEntity] round-trip emits.
///
/// The union's `fallbackUnion: 'unknown'` routes any `runtimeType` a build
/// does not know to [AgentUnknownEntity], which keeps five fields — and whose
/// generated `toJson` writes back the ORIGINAL discriminator rather than
/// `'unknown'`. A peer too old to know a variant therefore re-persists (and
/// re-syncs) a truncated row still tagged with the variant it could not read.
const Set<String> _unknownFallbackKeys = {
  'id',
  'agentId',
  'createdAt',
  'vectorClock',
  'deletedAt',
  'runtimeType',
};

/// Whether [json] is an older peer's [AgentUnknownEntity] round-trip of a
/// variant THIS build understands.
///
/// Without this, upgrading a client that had stored such a row makes every
/// read of it explode: the generated decoder dispatches on the preserved
/// discriminator and then demands required fields the older peer already
/// dropped (`status`, `brief`, …). The failure is an [ArgumentError] from an
/// enum converter, not a [FormatException], so sync cannot classify it as
/// permanently poisonous and retries it forever — and one such row fails the
/// whole batched read it lands in, not just itself.
///
/// The test is deliberately narrow: the payload must carry NO key outside
/// [_unknownFallbackKeys]. Genuine corruption or truncation of a real payload
/// keeps some of its own fields and so still throws, preserving the
/// poison-payload contract above. The content of the original nudge is
/// unrecoverable — the old peer discarded it on write — so the row degrades to
/// the same inert [AgentUnknownEntity] it already was on that peer, and never
/// surfaces, instead of taking a query down with it.
bool _isUnknownFallbackRoundTrip(Map<String, dynamic> json) {
  final runtimeType = json['runtimeType'];
  // An absent/unknown discriminator already lands on the fallback branch.
  if (runtimeType is! String || runtimeType == 'unknown') return false;
  return json.keys.every(_unknownFallbackKeys.contains);
}

/// Raw-JSON goal-spec validation BEFORE the generated decoder runs:
/// json_serializable truncates fractional numbers with `.toInt()`, so a
/// malformed `targetCount: 1.9` or `version: 1.9` must be rejected while
/// still visible.
void _validateGoalSpecJson(Map<String, dynamic> json) {
  if (json['runtimeType'] != 'goalSpecVersion') return;
  final version = json['version'];
  if (version is! num || version % 1 != 0 || version < 1) {
    throw FormatException(
      'goalSpecVersion.version must be a positive integer, was $version',
    );
  }
  final criteria = json['criteria'];
  if (criteria is! Map<String, dynamic>) {
    throw const FormatException('goalSpecVersion has no criteria tree');
  }
  final issues = GoalSpecValidator.criterionJsonIssues(criteria);
  if (issues.isNotEmpty) {
    throw FormatException('Invalid goal criteria: ${issues.join('; ')}');
  }
}

/// Cross-field rating validation the per-field converters cannot do.
/// One rule set for every nudge variant (ADR 0059): the histories carry the
/// same contracts whichever agent kind wrote them.
void _validateNudgeJson(Map<String, dynamic> json) {
  final runtimeType = json['runtimeType'];
  if (!AgentEntityTypes.nudgeTypes.contains(runtimeType)) {
    return;
  }
  final label = runtimeType == AgentEntityTypes.goalNudge
      ? 'goal nudge'
      : 'relationship nudge';
  final ratings = json['ratings'];
  if (ratings is List) {
    for (final entry in ratings) {
      if (entry is! Map<String, dynamic>) continue;
      final issues = nudgeRatingJsonIssues(entry);
      if (issues.isNotEmpty) {
        throw FormatException(
          'Invalid $label rating: ${issues.join('; ')}',
        );
      }
    }
  }
  final snoozeHistory = json['snoozeHistory'];
  if (snoozeHistory is List) {
    for (final entry in snoozeHistory) {
      if (entry is! Map<String, dynamic>) continue;
      final issues = nudgeSnoozeJsonIssues(entry);
      if (issues.isNotEmpty) {
        throw FormatException(
          'Invalid $label snooze: ${issues.join('; ')}',
        );
      }
    }
  }
  final dismissalHistory = json['dismissalHistory'];
  if (dismissalHistory is List) {
    for (final entry in dismissalHistory) {
      if (entry is! Map<String, dynamic>) continue;
      final issues = nudgeDayDismissalJsonIssues(entry);
      if (issues.isNotEmpty) {
        throw FormatException(
          'Invalid $label day dismissal: ${issues.join('; ')}',
        );
      }
    }
  }
}

// Both register generations. The `_v2` ids this build writes always carry
// `weekStart`, so they never reach the repair — but a generation the pattern
// does not know would be rejected as a poison payload rather than repaired,
// which is a worse failure than being redundant here.
final _canonicalWeekRollupId = RegExp(
  r'^week_rollup(?:_v2)?:(\d{4})-(\d{2})-(\d{2})$',
);

const _invalidLegacyWeekRollupMessage =
    'Legacy weekRollup is missing weekStart and its id is not a canonical '
    'Monday';

Map<String, dynamic> _repairLegacyWeekRollup(Map<String, dynamic> json) {
  if (json['runtimeType'] != 'weekRollup' || json['weekStart'] != null) {
    return json;
  }

  final id = json['id'];
  final match = id is String ? _canonicalWeekRollupId.firstMatch(id) : null;
  if (match == null) {
    throw const FormatException(_invalidLegacyWeekRollupMessage);
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  // UTC-typed: the id is a zone-free calendar key, so resolving it in the
  // reader's zone would make the derived weekStart reader-relative — the
  // divergence week rollups were made canonical to end.
  final weekStart = DateTime.utc(year, month, day);
  final isExactDate =
      weekStart.year == year &&
      weekStart.month == month &&
      weekStart.day == day;
  if (!isExactDate || weekStart.weekday != DateTime.monday) {
    throw const FormatException(_invalidLegacyWeekRollupMessage);
  }

  return <String, dynamic>{
    ...json,
    'weekStart': weekStart.toIso8601String(),
  };
}
