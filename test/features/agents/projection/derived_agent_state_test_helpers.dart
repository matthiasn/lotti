import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';

/// A milestone marker message — what `AgentSyncService.appendMilestone` emits.
AgentMessageEntity hMarker(
  String id,
  AgentMilestone milestone,
  DateTime createdAt, {
  DateTime? deletedAt,
}) {
  final message = makeTestMessage(
    id: id,
    kind: AgentMessageKind.system,
    createdAt: createdAt,
    metadata: AgentMessageMetadata(milestone: milestone),
  );
  return deletedAt == null ? message : message.copyWith(deletedAt: deletedAt);
}

DateTime hDay(int n) => DateTime(2024, 3, n);

/// One generated fold input: milestone markers and slot links with arbitrary
/// timestamps (ties included) for one agent, used to prove the fold is a pure
/// function of the *set* — i.e. it converges across arrival orders.
class GeneratedFoldScenario {
  const GeneratedFoldScenario({required this.markers, required this.links});

  final List<AgentMessageEntity> markers;
  final List<AgentLink> links;

  @override
  String toString() =>
      'GeneratedFoldScenario(markers: ${markers.length}, '
      'links: ${links.length})';
}

/// Arbitrary cache watermark values for all five watermark fields. Each int is
/// a day in `0..7`, where `0` encodes a null watermark and `1..7` encode
/// `hDay(n)` — the `1..7` range overlaps the generated marker days so cache and
/// log-derived watermarks tie, are above, and are below each other across runs.
class CacheWatermarks {
  const CacheWatermarks({
    required this.wake,
    required this.oneOnOne,
    required this.feedbackScan,
    required this.dailyWake,
    required this.weeklyReview,
  });

  final int wake;
  final int oneOnOne;
  final int feedbackScan;
  final int dailyWake;
  final int weeklyReview;

  static DateTime? hAt(int day) => day == 0 ? null : hDay(day);

  DateTime? get wakeAt => hAt(wake);
  DateTime? get oneOnOneAt => hAt(oneOnOne);
  DateTime? get feedbackScanAt => hAt(feedbackScan);
  DateTime? get dailyWakeAt => hAt(dailyWake);
  DateTime? get weeklyReviewAt => hAt(weeklyReview);

  @override
  String toString() =>
      'CacheWatermarks(wake: $wake, oneOnOne: $oneOnOne, '
      'feedbackScan: $feedbackScan, dailyWake: $dailyWake, '
      'weeklyReview: $weeklyReview)';
}

/// The later of two nullable timestamps — the reconcile law (`max`, null = "no
/// value"), recomputed in the test independent of the private `_laterOf`.
DateTime? hLaterOfOracle(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

extension AnyFoldScenario on glados.Any {
  glados.Generator<AgentMilestone> get milestone =>
      glados.AnyUtils(this).choose(AgentMilestone.values);

  glados.Generator<CacheWatermarks> get cacheWatermarks {
    glados.Generator<int> day() => glados.IntAnys(this).intInRange(0, 8);
    return glados.CombinableAny(this).combine5(
      day(),
      day(),
      day(),
      day(),
      day(),
      (int w, int o, int f, int d, int r) => CacheWatermarks(
        wake: w,
        oneOnOne: o,
        feedbackScan: f,
        dailyWake: d,
        weeklyReview: r,
      ),
    );
  }

  glados.Generator<GeneratedFoldScenario> get foldScenario =>
      glados.CombinableAny(this).combine2(
        // Marker specs: (milestone, day-of-month tie-prone in 1..6).
        glados.ListAnys(this).listWithLengthInRange(
          0,
          8,
          glados.CombinableAny(this).combine2(
            milestone,
            glados.IntAnys(this).intInRange(1, 7),
            (AgentMilestone m, int day) => (m, day),
          ),
        ),
        // Link specs: (slot 0..3, target 0..2, day 1..6, fromOtherAgent).
        glados.ListAnys(this).listWithLengthInRange(
          0,
          8,
          glados.CombinableAny(this).combine4(
            glados.IntAnys(this).intInRange(0, 4),
            glados.IntAnys(this).intInRange(0, 3),
            glados.IntAnys(this).intInRange(1, 7),
            glados.AnyUtils(this).choose(const [false, true]),
            (int slot, int target, int day, bool fromOther) =>
                (slot, target, day, fromOther),
          ),
        ),
        (
          List<(AgentMilestone, int)> markerSpecs,
          List<(int, int, int, bool)> linkSpecs,
        ) {
          final markers = [
            for (final (i, spec) in markerSpecs.indexed)
              hMarker('m$i', spec.$1, hDay(spec.$2)),
          ];
          final links = [
            for (final (i, spec) in linkSpecs.indexed)
              hSlotLink(
                index: i,
                slot: spec.$1,
                target: 'target-${spec.$2}',
                createdAt: hDay(spec.$3),
                fromId: spec.$4 ? 'other-agent-$i' : kTestAgentId,
              ),
          ];
          return GeneratedFoldScenario(markers: markers, links: links);
        },
      );
}

AgentLink hSlotLink({
  required int index,
  required int slot,
  required String target,
  required DateTime createdAt,
  required String fromId,
}) {
  final id = 'link-$index';
  return switch (slot % 4) {
    0 => makeTestAgentTaskLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    1 => makeTestAgentProjectLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    2 => makeTestAgentDayLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    _ => makeTestImproverTargetLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
  };
}
