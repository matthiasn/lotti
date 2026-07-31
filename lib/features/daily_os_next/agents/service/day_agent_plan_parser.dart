import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// Pure parsing/option helpers shared by the plan service. Library-private
// top-level functions so the class and the other parts call them
// unqualified.

/// The subset of [taskIds] that resolve to a live task this agent may
/// reference, mapped to the category each task belongs to.
///
/// Returns the category as well as the id because the same read establishes
/// both, and a block that references a task must be filed under *that task's*
/// category — see [parsePlannedBlock]. Resolving them separately is how the
/// two drifted apart.
///
/// One implementation on purpose. Task references reach a plan through two
/// doors — a fresh draft and an approved diff — and the isolation bug this
/// replaces existed because each door had its own idea of what counted as
/// allowed, with only one of them resolving the id at all.
Future<Map<String, String?>> resolveAllowedTaskIds({
  required JournalDb journalDb,
  required Iterable<String> taskIds,
  required Set<String> allowedCategoryIds,
}) async {
  final ids = taskIds.toSet();
  if (ids.isEmpty) return const <String, String?>{};
  final entities = await journalDb.journalEntityMapForIds(ids.toList());
  return {
    for (final entry in entities.entries)
      if (entry.value case final Task task)
        if (task.meta.deletedAt == null &&
            categoryAllowed(task.meta.categoryId, allowedCategoryIds))
          entry.key: task.meta.categoryId,
  };
}

/// The category a block belongs to, given the task it references.
///
/// A block that names a task is filed under *that task's* category, not
/// whichever one the model wrote: the block's category and its task were
/// validated against the agent's allow-set independently but never against each
/// other, so a block could carry a task from one area and bill its time to
/// another. `plannedMinutesByCategory` and every rollup built on it read this.
///
/// Derived rather than rejected, because the task's category is the only
/// correct answer — asking the model to guess it costs a round trip to learn
/// something already known. Safe by construction: [resolveAllowedTaskIds] only
/// returns tasks whose category this agent may touch, so the derived value is
/// always inside the allow-set the block was checked against.
///
/// Stated once and used at both doors — a fresh draft and an accepted diff —
/// because fixing only one of them is how the original defect arose.
/// [fallback] holds for a block with no task (buffers, breaks) and for a task
/// with no category, where nulling the block's would drop it out of every
/// per-category rollup.
String categoryForPlannedBlock({
  required String? taskId,
  required String fallback,
  required Map<String, String?> taskCategoryIds,
}) => taskId == null ? fallback : taskCategoryIds[taskId] ?? fallback;

/// Block states that represent a *plan* rather than a record of something that
/// already happened.
///
/// Used to decide whether a carried-forward block may change state: history
/// (`inProgress`, `completed`, `dropped`) is a legitimate progression for work
/// already on the plan, while adopting a plan state the baseline did not hold
/// would let a known block id be reused to place new work in the past.
const plannedBlockStatesGuardedFromThePast = <PlannedBlockState>{
  PlannedBlockState.drafted,
  PlannedBlockState.committed,
};

/// The earliest instant a *planned* block may start on [planDate], or null when
/// the day has not begun yet and the past has no meaning for it.
///
/// This is the **enforced** threshold, evaluated when the tool call lands.
DateTime? earliestPlannableStart({
  required DateTime planDate,
  required DateTime now,
}) => localDay(planDate) == localDay(now) ? now : null;

/// Clock granularity the advertised start snaps to, so the model is handed a
/// time a person would actually write down.
const advertisedStartGranularity = Duration(minutes: 5);

/// Minimum gap between the advertised start and the instant it was computed.
///
/// Covers the model's own thinking time — the window between rendering the
/// prompt and the guard evaluating `clock.now()`. Measured wake latencies ran
/// 13s to 152s, so three minutes clears the worst observed case.
///
/// Enforced separately from [advertisedStartGranularity] because snapping alone
/// does not guarantee it: at 09:59:59 the next five-minute boundary is one
/// second away, which reproduces exactly the failure this exists to prevent.
const minimumPlanningHeadroom = Duration(minutes: 3);

/// The earliest start the *prompt* advertises, or null when the day has not
/// begun.
///
/// Deliberately later than [earliestPlannableStart], and that asymmetry is the
/// whole point. The workflow carries the pre-inference planning snapshot into
/// `draft_day_plan`, so persistence validates the same floor that produced the
/// prompt instead of moving it while the model thinks. Advertising the raw
/// instant would still make the plan stale on arrival: it reads
/// "15:00:00.005877", sensibly starts the day at 15:00, and inference finishes
/// after that instant.
///
/// That is not hypothetical. Every sampled `lateStart` cell across both models
/// did exactly this and was rejected, 6/6, burning a whole round trip on the
/// most ordinary case there is — planning a day that has already started.
///
/// It is the first [advertisedStartGranularity] boundary at least
/// [minimumPlanningHeadroom] after [now], so the advertised value remains a
/// genuinely future slot when the tool call lands, while the shared snapshot
/// keeps validation deterministic.
DateTime? advertisedPlanningStart({
  required DateTime planDate,
  required DateTime now,
}) {
  final earliest = earliestPlannableStart(planDate: planDate, now: now);
  if (earliest == null) return null;
  final step = advertisedStartGranularity.inMinutes;
  final floor = DateTime(
    earliest.year,
    earliest.month,
    earliest.day,
    earliest.hour,
    earliest.minute - (earliest.minute % step),
  );
  // Walk forward rather than snapping once: the nearest boundary can be a
  // second away, which is no headroom at all.
  var candidate = floor;
  while (candidate.difference(earliest) < minimumPlanningHeadroom) {
    candidate = candidate.add(advertisedStartGranularity);
  }
  // Late enough and the walk runs out of day: at 23:58 it lands on 00:05
  // tomorrow, and `parsePlannedBlock` rejects anything outside the plan day —
  // so advertising it would steer the model into the very rejection this
  // function exists to prevent, at the other end of the day. Null means the
  // window is closed, which [planningWindowClosed] distinguishes from the
  // never-constrained future-day case.
  // Calendar arithmetic, not +24h: on a DST day adding a fixed duration to
  // local midnight lands on 01:00 or 23:00, which would either advertise into
  // tomorrow or close the window an hour early.
  final day = localDay(planDate);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  if (candidate.add(advertisedStartGranularity).isAfter(dayEnd)) return null;
  return candidate;
}

/// Parses a `HH:mm` working-hours boundary onto [day], or null when the string
/// is not one.
///
/// Null rather than a fallback: `workingHoursStart`/`End` are free-text config
/// that nothing else parses, so a malformed value must leave the budget
/// unstated rather than assert a wrong one the model would then plan against.
DateTime? workingHourOn(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  final base = localDay(day);
  return DateTime(base.year, base.month, base.day, hour, minute);
}

/// Working minutes still available on [planDate], or null when it cannot be
/// stated.
///
/// The model is otherwise asked to derive this from three separate places: the
/// capacity and working hours in the system prompt's planning defaults, and the
/// start it may plan from in the user message. It does not — measured as plans
/// running to 17:45 against a 17:00 day, and 780 minutes scheduled against 480
/// of capacity. Stating it is the same move as [advertisedPlanningStart]:
/// compute what we already know rather than asking the model to.
///
/// Bounded by capacity *and* by the clock, because either can be the binding
/// one: a full day is limited by how much the user can absorb, an afternoon
/// draft by how much of the day is left. Zero is a real answer — the working
/// day is over — and is stated rather than suppressed.
int? remainingWorkingMinutes({
  required DateTime planDate,
  required DateTime now,
  required int capacityMinutes,
  required String workingHoursStart,
  required String workingHoursEnd,
}) {
  final end = workingHourOn(planDate, workingHoursEnd);
  final dayStart = workingHourOn(planDate, workingHoursStart);
  if (end == null || dayStart == null) return null;
  // Same instant the model is told to build from, so the arithmetic it is
  // spared is the arithmetic it would have done.
  final advertised = advertisedPlanningStart(planDate: planDate, now: now);
  if (advertised == null &&
      planningWindowClosed(planDate: planDate, now: now)) {
    // The window section already says the day is over; a second number saying
    // the same thing invites the model to reconcile two signals.
    return null;
  }
  final from = advertised == null
      ? dayStart
      : (advertised.isAfter(dayStart) ? advertised : dayStart);
  final byClock = end.difference(from).inMinutes;
  if (byClock <= 0) return 0;
  return byClock < capacityMinutes ? byClock : capacityMinutes;
}

/// Whether today's planning window has run out: the plan is for today, but no
/// usable slot remains before midnight.
///
/// Distinct from "no constraint at all". Both leave [advertisedPlanningStart]
/// null, and collapsing them would let a wake at 23:58 plan freely from 09:00
/// this morning — the past-start guard would reject every block of it.
bool planningWindowClosed({
  required DateTime planDate,
  required DateTime now,
}) =>
    earliestPlannableStart(planDate: planDate, now: now) != null &&
    advertisedPlanningStart(planDate: planDate, now: now) == null;

/// Whether a fresh draft has no legal planning slot left today.
///
/// There are two independent closing boundaries: the configured working-hours
/// end and the final five-minute slot of the local calendar day. Keeping this
/// predicate shared between prompt construction and persistence prevents the
/// model from being told that the window is closed while the tool rejects the
/// only honest artifact for a fresh day: an empty plan.
bool draftPlanningWindowClosed({
  required DateTime planDate,
  required DateTime now,
  required int capacityMinutes,
  required String workingHoursStart,
  required String workingHoursEnd,
}) =>
    remainingWorkingMinutes(
          planDate: planDate,
          now: now,
          capacityMinutes: capacityMinutes,
          workingHoursStart: workingHoursStart,
          workingHoursEnd: workingHoursEnd,
        ) ==
        0 ||
    planningWindowClosed(planDate: planDate, now: now);

/// Validates and parses one model-emitted block into a [PlannedBlock],
/// throwing [DayAgentCaptureException] on any contract violation: a `cal`
/// type (no calendar reaches this agent), an out-of-allowlist category, `end`
/// not after `start`, a block outside the plan day, a *planned* today block
/// starting before [earliestDraftStart], an AI block missing its `reason`, or
/// a `taskId` outside [decidedTaskIds]/[allowedExistingTaskIds] — both of
/// which the caller resolves and category-filters. Defaults `type` to `ai` and
/// `state` to `drafted`, and mints a block id when none is supplied.
PlannedBlock parsePlannedBlock({
  required Object? raw,
  required DateTime day,
  required Set<String> allowedCategoryIds,
  required Map<String, String?> decidedTaskIds,
  required Map<String, String?> allowedExistingTaskIds,
  DateTime? earliestDraftStart,
  Map<String, PlannedBlock> baselineBlocks = const {},
}) {
  if (raw is! Map) {
    throw const DayAgentCaptureException('block must be an object');
  }
  final data = raw.cast<String, dynamic>();
  final type = optionalEnumArg(
    PlannedBlockType.values,
    optionalStringArg(data['type']),
  );
  final state = optionalEnumArg(
    PlannedBlockState.values,
    optionalStringArg(data['state']),
  );
  final blockType = type ?? PlannedBlockType.ai;
  // `cal` means "imported calendar event", and the day agent is shown none:
  // `DayAgentInterface.draftDayPlan` documents its `calendarBlocks` parameter
  // as deferred and `RealDayAgent` drops it, so no context section renders a
  // single event. A model-emitted `cal` block therefore always asserts an
  // import that never happened, and `DayAgentPlanEditor` then refuses to let
  // the user edit it — "block is calendar-owned, edit it in the source
  // calendar" — leaving a block they can neither change here nor find there.
  //
  // When calendar events are actually wired into the drafting context, this
  // rejection, the `cal` option in the tool schema, and a past-start exemption
  // for genuinely spanning events all come back together.
  if (blockType == PlannedBlockType.cal) {
    throw const DayAgentCaptureException(
      'cal blocks mirror imported calendar events, and none are available to '
      'this agent — use ai, manual, or buffer',
    );
  }
  final categoryId = requiredStringArg(data, 'categoryId');
  if (!categoryAllowed(categoryId, allowedCategoryIds)) {
    throw DayAgentCaptureException('categoryId $categoryId is not allowed');
  }
  final start = requiredDateTimeArg(data, 'start');
  final end = requiredDateTimeArg(data, 'end');
  if (!end.isAfter(start)) {
    throw const DayAgentCaptureException('block end must be after start');
  }
  final blockState = state ?? PlannedBlockState.drafted;
  final dayStart = localDay(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
    throw const DayAgentCaptureException(
      'blocks must stay within the planDate day',
    );
  }
  // Nothing the agent *plans* may start in the past. Only states recording
  // something that already happened are exempt — `inProgress`, `completed`
  // and `dropped` are history a re-draft legitimately carries forward.
  //
  // `committed` is not history: it is a plan the user agreed to, and writing a
  // new block as `committed` was the remaining way to place work before the
  // current time. Observed live, alongside the earlier trick of relabelling a
  // past-starting block `buffer` to slip an ai/manual-only guard — the same
  // probing, one field over. Guarding by what a state *means* closes both.
  final blockId = optionalStringArg(data['id']);
  // One rule for the past, keyed on evidence rather than on the state label:
  // a block that starts before now is only acceptable if the baseline already
  // had that block at that time. Anything else is either planning the past or
  // fabricating history, and the state name cannot tell the two apart — a
  // fresh block claiming `completed` at 09:00 is exactly as invented as a
  // fresh `committed` one, which is why guarding a list of "planning" states
  // left the other half of the bypass open.
  //
  // State may still progress on a carried block (in-progress work finishes),
  // but it may not become a *plan* state that the baseline did not already
  // hold — otherwise a known id could be reused to slip a new committed block
  // into a past slot.
  final baseline = blockId == null ? null : baselineBlocks[blockId];
  // A *plan* state in the past is only acceptable as a faithful repeat of a
  // block the plan already had: same id, same start, and the same state it
  // already held. Matching on id and start alone would let a known 09:00 id
  // be reused to drop a brand-new `committed` block into that slot,
  // rewriting approved work without the refinement approval that normally
  // gates it.
  //
  // History states (`inProgress`, `completed`, `dropped`) stay exempt. They
  // can legitimately have no baseline: the first draft of the day may happen
  // in the afternoon, and the capture is where the agent learns what the
  // morning actually contained. Whether a model should be able to *invent*
  // that history is a real question — the eval's `noHistoryFabrication`
  // measures it — but it is a product decision about what a plan may record,
  // not something to settle by tightening a guard mid-fix.
  final carriedForward =
      baseline != null &&
      baseline.startTime == start &&
      baseline.state == blockState;
  if (earliestDraftStart != null &&
      plannedBlockStatesGuardedFromThePast.contains(blockState) &&
      start.isBefore(earliestDraftStart) &&
      !carriedForward) {
    throw const DayAgentCaptureException(
      'blocks planned for today must not start before current time',
    );
  }
  // `committed` asserts that the *user approved this block*. Only two things
  // may say that, and neither is the model: the user committing the day
  // through the UI, and `acceptPlanDiff` on an already-agreed plan. So the
  // only legitimate `committed` block the model can emit is a faithful repeat
  // of one the plan already had — which is what a re-draft over an agreed
  // plan does.
  //
  // Unconditional, not just for the past. The past-start guard above happened
  // to catch the backdated case, which made this look covered; a future-dated
  // `committed` block sailed through and persisted, projecting to the UI as
  // agreed work the user never agreed to. Observed in 4 of 9 archived eval
  // runs, always on `bindingDirective`, always a single 09:00 block titled
  // "Already scheduled" — the model depicting the directive's
  // `alreadyScheduledMinutes` as existing commitments. A fair thing to want to
  // say, and `drafted` says it without claiming the user's verdict.
  if (blockState == PlannedBlockState.committed) {
    if (!carriedForward) {
      throw const DayAgentCaptureException(
        'blocks may not be created as committed — committed means the user '
        'approved this block, which only they can do. Use drafted',
      );
    }
    // The baseline block verbatim, not the model's version of it. Matching on
    // id, start and state proves the block *existed* and was approved; it says
    // nothing about the end time, title, task, category, type, reason or note
    // the model wrote around them. Rebuilding from those fields would let a
    // re-draft rewrite approved work under the user's prior consent — the same
    // defect as inventing a committed block, wearing a real block's id.
    //
    // Changing a committed block is what `propose_plan_diff` is for, where the
    // user sees the change and accepts it.
    return baseline;
  }
  final reason = optionalStringArg(data['reason']);
  if (blockType == PlannedBlockType.ai && reason == null) {
    throw const DayAgentCaptureException(
      'AI planned blocks require a non-empty reason',
    );
  }
  final taskId = optionalStringArg(data['taskId']);
  // Both sets are resolved and category-filtered by the caller, which is the
  // point: `decidedTaskIds` arrives as a `draft_day_plan` argument the model
  // writes itself, so treating it as a permission set let a model reference
  // any task — deleted, non-existent, or in a category this agent may not
  // touch — simply by echoing the id into its own call, defeating the check
  // the sibling branch applies.
  if (taskId != null &&
      !decidedTaskIds.containsKey(taskId) &&
      !allowedExistingTaskIds.containsKey(taskId)) {
    throw DayAgentCaptureException(
      'taskId $taskId is not an allowed task for this plan',
    );
  }
  final effectiveCategoryId = categoryForPlannedBlock(
    taskId: taskId,
    fallback: categoryId,
    taskCategoryIds: {...allowedExistingTaskIds, ...decidedTaskIds},
  );
  return PlannedBlock(
    id: blockId ?? 'block_${_uuid.v4()}',
    categoryId: effectiveCategoryId,
    startTime: start,
    endTime: end,
    note: optionalStringArg(data['note']),
    taskId: taskId,
    title: requiredStringArg(data, 'title'),
    type: blockType,
    state: blockState,
    reason: reason,
  );
}

/// Validates and parses one model-emitted energy band into a
/// [DayAgentEnergyBand], throwing [DayAgentCaptureException] when `end` is not
/// after `start`, the band falls outside the plan day, or `level` is not one
/// of `high`/`low`/`secondWind`.
DayAgentEnergyBand parseEnergyBand({
  required Object? raw,
  required DateTime day,
}) {
  if (raw is! Map) {
    throw const DayAgentCaptureException('energyBand must be an object');
  }
  final data = raw.cast<String, dynamic>();
  final start = requiredDateTimeArg(data, 'start');
  final end = requiredDateTimeArg(data, 'end');
  if (!end.isAfter(start)) {
    throw const DayAgentCaptureException(
      'energyBand end must be after start',
    );
  }
  final dayStart = localDay(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  if (start.isBefore(dayStart) || end.isAfter(dayEnd)) {
    throw const DayAgentCaptureException(
      'energyBands must stay within the planDate day',
    );
  }
  final level = optionalEnumArg(
    DayAgentEnergyLevel.values,
    requiredStringArg(data, 'level'),
  );
  if (level == null) {
    throw const DayAgentCaptureException(
      'energyBand level must be high, low, or secondWind',
    );
  }
  return DayAgentEnergyBand(
    start: start,
    end: end,
    level: level,
    label: requiredStringArg(data, 'label'),
  );
}

/// The distinct tasks referenced by [blocks], in first-seen order, as
/// [PinnedTaskRef]s — the persisted record of which tasks the plan pins to the
/// day.
List<PinnedTaskRef> pinnedTasksFor(List<PlannedBlock> blocks) {
  final seen = <String>{};
  final out = <PinnedTaskRef>[];
  for (final block in blocks) {
    final taskId = block.taskId;
    if (taskId == null || !seen.add(taskId)) continue;
    out.add(
      PinnedTaskRef(
        taskId: taskId,
        categoryId: block.categoryId,
        sortOrder: out.length,
      ),
    );
  }
  return out;
}

/// Total scheduled minutes across [blocks], excluding dropped blocks — the
/// figure compared against the day's capacity.
int scheduledMinutesFor(List<PlannedBlock> blocks) {
  return blocks
      .where((block) => block.state != PlannedBlockState.dropped)
      .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
}

/// Rejects active blocks outside the configured working-hours window.
///
/// The prompt advertises these bounds, but model compliance is not a storage
/// invariant. A measured Qwen draft stayed under `capacityMinutes` only because
/// it left a clock gap, then ran its final block an hour past
/// [workingHoursEnd]. Persisting that plan traded one constraint for another
/// and made the draft look usable when it was not.
///
/// Malformed free-text working-hours values leave that boundary unenforced,
/// matching [remainingWorkingMinutes]: inventing a fallback would reject a
/// plan against hours the user did not configure.
void validateDraftWorkingHours({
  required List<PlannedBlock> blocks,
  required DateTime planDate,
  required String workingHoursStart,
  required String workingHoursEnd,
}) {
  final start = workingHourOn(planDate, workingHoursStart);
  final end = workingHourOn(planDate, workingHoursEnd);
  for (final block in blocks) {
    if (block.state == PlannedBlockState.dropped) continue;
    if (start != null && block.startTime.isBefore(start)) {
      throw DayAgentCaptureException(
        'block "${block.title}" starts before configured working hours '
        '($workingHoursStart)',
      );
    }
    if (end != null && block.endTime.isAfter(end)) {
      throw DayAgentCaptureException(
        'block "${block.title}" ends after configured working hours '
        '($workingHoursEnd). Shorten or omit work and surface the '
        'overCommitted conflict instead.',
      );
    }
  }
}

/// Serializes a persisted [DayPlanEntity] into the JSON tool-result shape
/// returned to the model (plan/day ids, capacity vs. scheduled minutes, and
/// each block + energy band).
Map<String, Object?> planJson(DayPlanEntity plan) => {
  'planId': plan.id,
  'dayId': plan.dayId,
  'captureId': plan.captureId,
  'planDate': plan.planDate.toIso8601String(),
  'state': 'drafted',
  'capacityMinutes': plan.capacityMinutes,
  'scheduledMinutes': plan.scheduledMinutes,
  'blocks': [for (final block in plan.data.plannedBlocks) blockJson(block)],
  'energyBands': [for (final band in plan.energyBands) band.toJson()],
};

Map<String, Object?> blockJson(PlannedBlock block) => {
  'id': block.id,
  'title': block.title,
  'taskId': block.taskId,
  'categoryId': block.categoryId,
  'start': block.startTime.toIso8601String(),
  'end': block.endTime.toIso8601String(),
  'type': block.type.name,
  'state': block.state.name,
  'reason': block.reason,
  'note': block.note,
};

List<Object?> objectListArg(Object? raw, String name) {
  if (raw == null) return const <Object?>[];
  if (raw is List) return raw;
  throw DayAgentCaptureException('$name must be an array');
}

List<String> stringListArg(Object? raw) {
  if (raw == null) return const <String>[];
  if (raw is! List) {
    throw const DayAgentCaptureException('decidedTaskIds must be an array');
  }
  final out = <String>[];
  for (final value in raw) {
    final parsed = optionalStringArg(value);
    if (parsed == null) {
      throw const DayAgentCaptureException(
        'decidedTaskIds must contain non-empty strings',
      );
    }
    out.add(parsed);
  }
  return out;
}

DateTime requiredDateTimeArg(Map<String, dynamic> args, String key) {
  final date = optionalDateTimeArg(args[key]);
  if (date == null) {
    throw DayAgentCaptureException(
      '$key must be a valid ISO-8601 date-time',
    );
  }
  return date;
}

String requiredStringArg(Map<String, dynamic> args, String key) {
  final value = optionalStringArg(args[key]);
  if (value == null) {
    throw DayAgentCaptureException('$key must not be empty');
  }
  return value;
}

String? optionalStringArg(Object? value) {
  if (value is! String) return null;
  return blankToNull(value);
}

int? optionalIntArg(Object? value) {
  if (value is int) return value;
  if (value is num) {
    if (value % 1 != 0) {
      throw const DayAgentCaptureException('value must be an integer');
    }
    return value.toInt();
  }
  return null;
}

DateTime? optionalDateTimeArg(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

T? optionalEnumArg<T extends Enum>(List<T> values, String? raw) {
  if (raw == null) return null;
  return parseEnumByName(values, raw);
}

String? blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool categoryAllowed(String? categoryId, Set<String>? allowed) {
  if (allowed == null || allowed.isEmpty) return true;
  return categoryId != null && allowed.contains(categoryId);
}

DateTime? dateFromDayId(String dayId) {
  const prefix = 'dayplan-';
  if (!dayId.startsWith(prefix)) return null;
  return DateTime.tryParse(dayId.substring(prefix.length));
}

/// Strips the `day_agent_plan:` prefix from a plan entity id to recover its
/// bare `dayId`, returning the input unchanged when the prefix is absent.
String dayIdFromPlanEntityId(String planEntityId) {
  const prefix = 'day_agent_plan:';
  if (planEntityId.startsWith(prefix)) {
    return planEntityId.substring(prefix.length);
  }
  return planEntityId;
}

/// Resolves a model-supplied `itemIndices` selection into a sorted, unique
/// index list. A null selection means "all items"; any out-of-range index
/// throws [DayAgentCaptureException].
List<int> selectIndices({
  required List<int>? itemIndices,
  required int itemCount,
}) {
  if (itemIndices == null) {
    return [for (var i = 0; i < itemCount; i++) i];
  }
  final out = <int>{};
  for (final index in itemIndices) {
    if (index < 0 || index >= itemCount) {
      throw DayAgentCaptureException(
        'itemIndex $index is out of range for a set with $itemCount items',
      );
    }
    out.add(index);
  }
  return out.toList()..sort();
}
