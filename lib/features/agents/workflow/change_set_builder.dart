import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger_status.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_item_dedup.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'change_set_batch_exploder.dart';

/// Resolves a checklist item's current state from its ID.
///
/// Returns `null` if the item cannot be found.
typedef ChecklistItemStateResolver =
    Future<({String? title, bool? isChecked, bool? isArchived})?> Function(
      String itemId,
    );

/// Resolves the set of existing checklist item titles for the target task.
///
/// Returns normalized (lowercased, trimmed) titles so that title-based
/// deduplication for `add_checklist_item` is case-insensitive.
typedef ExistingChecklistTitlesResolver = Future<Set<String>> Function();

/// Resolves a human-readable label name from its ID.
///
/// Returns `null` if the label cannot be found.
typedef LabelNameResolver = Future<String?> Function(String labelId);

/// Resolves the set of label IDs already assigned to the target task.
///
/// Used to suppress redundant label assignment proposals.
typedef ExistingLabelIdsResolver = Future<Set<String>> Function();

/// Result of adding batch items to a [ChangeSetBuilder].
class BatchAddResult {
  const BatchAddResult({
    required this.added,
    required this.skipped,
    this.redundant = 0,
    this.redundantDetails = const [],
    this.rejected = 0,
    this.rejectedDetails = const [],
  });

  /// Number of valid items that were added.
  final int added;

  /// Number of array elements that were skipped (not `Map<String, dynamic>`).
  final int skipped;

  /// Number of items suppressed because they propose no actual change.
  final int redundant;

  /// Human-readable descriptions of each suppressed redundant item,
  /// e.g. `'"Buy groceries" is already checked'`.
  final List<String> redundantDetails;

  /// Number of items rejected because they reference an entity that does not
  /// exist — a hallucinated id the model invented. Distinct from [redundant]
  /// (a real but no-op change) and [skipped] (a malformed array element).
  final int rejected;

  /// Human-readable per-item rejection reasons, each naming the bad id so the
  /// model can stop proposing it, e.g.
  /// `'label "abc123" does not exist — do not invent ids'`.
  final List<String> rejectedDetails;
}

/// Accumulates deferred tool calls during an agent wake and produces a
/// [ChangeSetEntity] at the end.
///
/// Batch tools (e.g., `add_multiple_checklist_items`) are exploded into
/// individual [ChangeItem] entries so each element can be independently
/// confirmed or rejected by the user.
class ChangeSetBuilder {
  ChangeSetBuilder({
    required this.agentId,
    required this.taskId,
    required this.threadId,
    required this.runKey,
    this.checklistItemStateResolver,
    this.existingChecklistTitlesResolver,
    this.labelNameResolver,
    this.existingLabelIdsResolver,
    this.domainLogger,
  });

  /// The agent instance ID.
  final String agentId;

  /// The journal entity being modified.
  final String taskId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  /// Optional resolver for checklist item state. When provided, the builder
  /// looks up the current title and checked state of checklist items that the
  /// LLM references by ID only (without including the title in the tool args).
  /// Also used to detect and suppress redundant updates.
  final ChecklistItemStateResolver? checklistItemStateResolver;

  /// Optional resolver for existing checklist item titles. When provided,
  /// `add_checklist_item` proposals are checked against existing titles
  /// (case-insensitive) and suppressed if a match is found.
  final ExistingChecklistTitlesResolver? existingChecklistTitlesResolver;

  /// Optional resolver for label names. When provided, human-readable
  /// summaries for `assign_task_label` items include the label name.
  final LabelNameResolver? labelNameResolver;

  /// Optional resolver for label IDs already assigned to the task. When
  /// provided, `assign_task_label` proposals for already-assigned labels
  /// are suppressed.
  final ExistingLabelIdsResolver? existingLabelIdsResolver;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  final List<ChangeItem> _items = [];
  static const _uuid = Uuid();

  /// Fingerprints of items a previous [build] already wrote.
  ///
  /// The wake flushes at every turn boundary so suggestions reach the user
  /// while the agent is still working, rather than all at once when the wake
  /// ends. Each flush must append only what it added.
  ///
  /// Keyed on fingerprint rather than a count because [_items] is not
  /// append-only — a fresh `update_running_timer` proposal drops the earlier
  /// one — so any positional watermark would slide onto the wrong items.
  /// Every add path rejects a duplicate fingerprint, so the key is unique.
  final _flushedFingerprints = <String>{};

  /// The change set this builder's flushed items live in, once one exists.
  ///
  /// Later flushes append into this same entity, so a wake produces exactly
  /// one card no matter how many turns it took.
  ChangeSetEntity? _persistedSet;

  /// Whether the inbox alert for this wake has been raised.
  ///
  /// Only the end-of-wake build raises it (see [notifyTaskNeedsAttention]),
  /// and it must do so even when incremental flushes already wrote every item
  /// and left it with nothing to persist.
  bool _notified = false;

  /// Lazily-resolved existing checklist titles (normalized), cached across
  /// a single batch to avoid repeated DB lookups.
  Set<String>? _cachedExistingTitles;

  /// Lazily-resolved existing label IDs, cached across a single batch.
  Set<String>? _cachedExistingLabelIds;

  /// All items accumulated so far.
  List<ChangeItem> get items => List.unmodifiable(_items);

  /// Structural fingerprints (`toolName + args`) of every item proposed this
  /// wake. The workflow passes these to
  /// `SuggestionRetractionService.applyStaged` so a retraction of an item the
  /// agent is simultaneously re-proposing is suppressed — otherwise the
  /// retract-then-re-add churn makes a stable suggestion vanish and reappear
  /// under the user.
  Set<String> get proposedFingerprints =>
      _items.map(ChangeItem.fingerprint).toSet();

  /// Whether any deferred items have been added.
  bool get hasItems => _items.isNotEmpty;

  /// Add a single tool call as a change item.
  ///
  /// For batch tools listed in [AgentToolRegistry.explodedBatchTools], use
  /// [addBatchItem] instead — this method does NOT auto-explode.
  ///
  /// For `add_checklist_item`, checks against existing titles and returns
  /// a redundancy detail if the title already exists. Returns `null` when
  /// the item was added successfully.
  Future<String?> addItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String humanSummary,
  }) async {
    // Within-wake fingerprint dedup: skip if an identical item is already
    // queued in this builder (e.g. model calling update_task_priority twice).
    final fingerprint = ChangeItem.fingerprintFromParts(toolName, args);
    if (_items.any((item) => ChangeItem.fingerprint(item) == fingerprint)) {
      return 'Already queued — this exact $toolName proposal was already '
          'recorded. Do NOT call this tool again with the same arguments. '
          'Proceed to the next tool or finish your analysis.';
    }

    final displayKey = ChangeItem.displayDuplicateKeyFromParts(
      toolName,
      humanSummary,
      args: args,
    );
    if (displayKey != null &&
        _items.any(
          (item) => ChangeItem.displayDuplicateKey(item) == displayKey,
        )) {
      return 'Already queued — this exact visible $toolName proposal was '
          'already recorded. Do NOT call this tool again with the same '
          'user-facing summary. Proceed to the next tool or finish your '
          'analysis.';
    }

    if (toolName == TaskAgentToolNames.updateRunningTimer) {
      final timerId = runningTimerIdFromArgs(args);
      _items.removeWhere(
        (item) => isRunningTimerUpdateForTimer(item, timerId),
      );
    }

    // Check for title-based redundancy on add_checklist_item.
    if (toolName == TaskAgentToolNames.addChecklistItem) {
      final existingTitles = await _resolveExistingTitles();
      final detail = ChangeSetBatchExplosion._checkAddRedundancy(
        toolName,
        args,
        existingTitles,
      );
      if (detail != null) return detail;

      // Track the title so subsequent addItem calls see it.
      final title = args['title'];
      if (title is String) {
        final normalized = title.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          existingTitles.add(normalized);
        }
      }
    }

    _items.add(
      ChangeItem(
        toolName: toolName,
        args: args,
        humanSummary: humanSummary,
      ),
    );
    return null;
  }

  /// Flush the items staged since the last call into the [ChangeSetEntity].
  ///
  /// Safe to call repeatedly across a wake, and the wake does: the workflow
  /// flushes at every turn boundary so proposals surface while the agent is
  /// still working rather than only when it finishes. Items are never written
  /// twice, and a flush that stages nothing new is a no-op that returns the
  /// set as it stands.
  ///
  /// Set [incremental] for a mid-wake flush. Such a flush writes only to the
  /// set this builder created — never to a pre-wake set, and never to one the
  /// user has resolved — and holds back split groups so a follow-up task and
  /// its checklist migrations stay atomic. The end-of-wake call leaves
  /// [incremental] false: by then staged retractions have been applied, so it
  /// is safe to consolidate the pre-wake sets and release the held groups,
  /// leaving the user with exactly one card.
  ///
  /// Items that already appear in [existingPendingSets] (matched by
  /// `toolName` + `args`) are silently dropped to avoid showing the user
  /// duplicate proposals across consecutive agent wakes. Pending, rejected,
  /// and deferred items are included in the dedup set so the agent cannot
  /// re-propose a mutation the user already rejected or one that is still
  /// awaiting review. Confirmed and retracted items are deliberately
  /// excluded — confirmed items were already applied, and retracted items
  /// are agent self-corrections that should not block a later, intentional
  /// re-proposal after the task context has changed.
  /// Existing sets are re-read from the repository before this check so
  /// mid-wake confirmations or retractions are honored during deduplication.
  ///
  /// [rejectedFingerprints] contains fingerprints reconstructed from
  /// persisted [ChangeDecisionEntity] records whose verdict was `rejected`.
  /// These are merged into the dedup set so that items the user rejected
  /// in a previous (now-resolved) change set are still blocked.
  /// [rejectedDisplayKeys] applies the same sticky rejection rule to
  /// verbatim user-facing summaries whose tool arguments changed shape.
  ///
  /// When existing pending change sets exist, all their items are
  /// consolidated into a single set together with the new items. Any
  /// surplus sets are marked as [ChangeSetStatus.resolved] so they no
  /// longer appear in the UI or future queries.
  ///
  /// Returns the persisted set, or `null` when nothing has ever survived
  /// deduplication.
  Future<ChangeSetEntity?> build(
    AgentSyncService syncService, {
    List<ChangeSetEntity> existingPendingSets = const [],
    Set<String> rejectedFingerprints = const {},
    Set<String> rejectedDisplayKeys = const {},
    bool incremental = false,
  }) async {
    // Only the items staged since the previous flush are persisted here.
    // Everything in [_flushedFingerprints] already lives in [_persistedSet],
    // and re-running them through the append below would duplicate them.
    final pendingItems = _items
        .where(
          (item) =>
              !_flushedFingerprints.contains(ChangeItem.fingerprint(item)) &&
              // Split groups (a `create_follow_up_task` and the
              // `migrate_checklist_item`s targeting its placeholder, which
              // share a groupId) must land together. Surfacing the follow-up
              // alone lets the user reject it mid-wake; the cascade that
              // rejects its migrations only sees the items present at that
              // moment, so migrations flushed afterwards would reference a
              // rejected placeholder and could never be confirmed.
              !(incremental && item.groupId != null),
        )
        .toList(growable: false);
    // A final build must still fold the pre-wake sets that incremental
    // flushes were forbidden to touch — even when every staged item has
    // already been written, which is the common case after a multi-turn wake.
    // Returning early there would leave the task with two open cards.
    //
    // Gated on this builder having written a set: a wake that proposed
    // nothing at all must stay a no-op and leave existing sets alone, as it
    // did before flushing became incremental.
    final mayNeedConsolidation =
        !incremental && _persistedSet != null && existingPendingSets.isNotEmpty;
    if (pendingItems.isEmpty && !mayNeedConsolidation) {
      return incremental ? _persistedSet : raiseInboxAlert(syncService);
    }

    // Re-read everything that could carry a duplicate, so dedup sees mid-wake
    // user decisions. This is a wider set than what we are willing to *write*
    // to — see [writableSets] below.
    final dedupSources = <ChangeSetEntity>[
      ...existingPendingSets,
      ?_persistedSet,
    ];
    final freshExistingSets = await Future.wait(
      dedupSources.map((cs) async {
        final freshEntity = await syncService.repository.getEntity(cs.id);
        return freshEntity is ChangeSetEntity ? freshEntity : cs;
      }),
    );

    // What this flush may merge into and retire.
    //
    // An incremental flush writes ONLY to the set this wake created. It must
    // not consolidate the pre-wake sets: doing so retires them, which marks
    // their pending items retracted and copies them into the survivor as
    // pending — and the end-of-wake `applyStaged` then skips the original row
    // it staged (no longer pending), leaving the copy open forever. The final
    // build runs after retractions have landed, so it consolidates safely.
    //
    // A set the user resolved mid-wake is excluded either way: appending
    // pending items to a `resolved` row would persist a proposal that pending
    // queries never return, so it would be invisible in both the UI and the
    // ledger.
    final ownSetId = _persistedSet?.id;
    final writableSets = [
      for (final cs in freshExistingSets)
        if (isPendingLike(cs.status) && (!incremental || cs.id == ownSetId)) cs,
    ];
    // Spans every item proposed this wake, flushed or not: a running-timer
    // update this wake already landed must not block its own successor.
    final proposedRunningTimerIds = runningTimerIds(_items);

    // Extract items from existing change sets that should block a new
    // identical proposal. Confirmed items were applied; retracted items
    // are agent self-corrections that must not block re-proposal after
    // material change.
    final existingItems = [
      for (final cs in freshExistingSets)
        for (final item in cs.items)
          if (item.status != ChangeItemStatus.confirmed &&
              item.status != ChangeItemStatus.retracted &&
              !(isRunningTimerUpdate(item) &&
                  item.status == ChangeItemStatus.pending &&
                  proposedRunningTimerIds.contains(runningTimerId(item))))
            item,
    ];

    final deduped = pendingItems.isEmpty
        ? const <ChangeItem>[]
        : deduplicateItems(
            pendingItems,
            existingItems,
            rejectedFingerprints: rejectedFingerprints,
            rejectedDisplayKeys: rejectedDisplayKeys,
          );
    // Items dropped by dedup are deliberately NOT marked flushed. The wake
    // applies staged retractions only at the end, just before the final
    // build, so an item this flush suppressed against a still-open proposal
    // gets one more chance once that proposal is gone — which is what the
    // end-of-wake-only behavior gave it.
    // Nothing new to write. Fall through only for the consolidation-only pass
    // described above, and only when there is a second writable set to fold —
    // otherwise this is the pre-existing "nothing survived dedup" no-op.
    final consolidationOnly = mayNeedConsolidation && writableSets.length >= 2;
    if (deduped.isEmpty && !consolidationOnly) {
      return incremental ? _persistedSet : raiseInboxAlert(syncService);
    }

    final dedupedRunningTimerIds = runningTimerIds(deduped);
    final supersededRunningTimerItems = dedupedRunningTimerIds.isNotEmpty
        ? locatePendingRunningTimerUpdates(
            writableSets,
            dedupedRunningTimerIds,
          )
        : const <
            ({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})
          >[];
    final currentExistingSets = supersededRunningTimerItems.isEmpty
        ? writableSets
        : markItemsRetracted(writableSets, supersededRunningTimerItems);
    final currentExistingSetsById = {
      for (final cs in currentExistingSets) cs.id: cs,
    };

    await _recordSupersededRunningTimerRetractions(
      syncService,
      supersededRunningTimerItems,
    );

    if (writableSets.isNotEmpty) {
      // Consolidate: pick the newest set as the survivor, collect all
      // items from every set, append the new deduplicated items, and
      // mark all other sets as resolved so the UI shows exactly one card.
      // On a later flush this collapses to the set this builder already
      // wrote, so the wake keeps appending to one card instead of opening
      // a fresh one per turn.
      final staleWinner = writableSets.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );

      final survivor = currentExistingSetsById[staleWinner.id] ?? staleWinner;

      // Gather items from non-survivor sets that aren't already in the
      // survivor or in the new deduped items.
      final knownFingerprints = {
        ...survivor.items.map(ChangeItem.fingerprint),
        ...deduped.map(ChangeItem.fingerprint),
      };

      final otherItems = <ChangeItem>[];
      for (final cs in writableSets) {
        if (cs.id != survivor.id) {
          final current = currentExistingSetsById[cs.id] ?? cs;
          for (final item in current.items) {
            if (knownFingerprints.add(ChangeItem.fingerprint(item))) {
              otherItems.add(item);
            }
          }
        }
      }

      final merged = survivor.copyWith(
        items: [...survivor.items, ...otherItems, ...deduped],
      );
      await syncService.upsertEntity(merged);

      // Mark all non-survivor sets as resolved so they disappear from
      // pending queries and the UI. Pending items in those retired rows are
      // marked retracted because their actionable copy now lives in the
      // survivor; leaving embedded `pending` items inside a resolved parent
      // makes the proposal ledger report stale open suggestions.
      for (final cs in writableSets) {
        if (cs.id != survivor.id) {
          final current = currentExistingSetsById[cs.id] ?? cs;
          await syncService.upsertEntity(retireConsolidatedSet(current));
        }
      }

      _flushedFingerprints.addAll(deduped.map(ChangeItem.fingerprint));
      _persistedSet = merged;
      if (!incremental) {
        _notified = true;
        await notifyTaskNeedsAttention(merged);
      }
      return merged;
    }

    // No existing set — create a new one.
    final entity =
        AgentDomainEntity.changeSet(
              id: _uuid.v4(),
              agentId: agentId,
              taskId: taskId,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: List.unmodifiable(deduped),
              createdAt: clock.now(),
              vectorClock: null,
            )
            as ChangeSetEntity;

    await syncService.upsertEntity(entity);
    _flushedFingerprints.addAll(deduped.map(ChangeItem.fingerprint));
    _persistedSet = entity;
    if (!incremental) {
      _notified = true;
      await notifyTaskNeedsAttention(entity);
    }
    return entity;
  }

  /// Raises the wake's single inbox alert for whatever has been flushed.
  ///
  /// Called by the end-of-wake build — including when it has nothing left to
  /// write, the normal outcome once incremental flushes have persisted every
  /// item, because otherwise the bell would never ring for a wake whose
  /// proposals all landed mid-conversation. Also called from the workflow's
  /// failure path, where `WakeOutputWriter` never runs but the flushed
  /// suggestions survive on disk and still deserve an alert.
  ///
  /// Re-reads the set before alerting: [_persistedSet] is the snapshot this
  /// builder wrote, and the card has been on screen since the first flush, so
  /// the user may have resolved items on it. Alerting from the stale snapshot
  /// would report an inflated pending count, or raise a fresh active row for a
  /// card the user already cleared.
  ///
  /// Idempotent — at most one alert per wake, whichever caller gets there
  /// first.
  Future<ChangeSetEntity?> raiseInboxAlert(AgentSyncService syncService) async {
    final persisted = _persistedSet;
    if (_notified || persisted == null) return persisted;
    _notified = true;

    ChangeSetEntity current;
    try {
      final latest = await syncService.repository.getEntity(persisted.id);
      current = latest is ChangeSetEntity ? latest : persisted;
    } catch (e) {
      // Alerting is fire-and-forget (see [notifyTaskNeedsAttention]) and must
      // never fail a wake. Skip rather than fall back to the snapshot: alerting
      // from stale items is the very thing this re-read exists to prevent.
      domainLogger?.log(
        LogDomain.agentWorkflow,
        'Skipping inbox alert — could not re-read the flushed change set',
        subDomain: 'changeSetBuilder',
      );
      return persisted;
    }

    // A set the user fully resolved needs no alert; `notifyTaskNeedsAttention`
    // makes the same call per item via its pending count.
    if (!isPendingLike(current.status)) return persisted;

    await notifyTaskNeedsAttention(current);
    return persisted;
  }

  /// Fires (or refreshes) a `taskSuggestion` row in the synced-notifications
  /// inbox so the bell badge surfaces the proposals that need user attention.
  ///
  /// The notification id is keyed on the **change-set id**, not the task id,
  /// because the merge in `NotificationsDb.upsertNotification` keeps the
  /// earliest non-null `actedOnAt`/`deletedAt` (the sync convergence
  /// contract). Once the user taps or dismisses one inbox row, that row id
  /// can never be made active again. Using the change-set id lets a fresh
  /// agent wave land on a fresh durable row; `NotificationRepository` then
  /// serializes task-suggestion mutations and retracts every older open row
  /// for the same task so the bell still exposes at most one active row per
  /// task.
  ///
  /// Fired only by the end-of-wake build, never by an incremental flush. Two
  /// reasons, both consequences of a flush writing its own set: the count
  /// would come from that set alone while `createTaskSuggestion` retracts the
  /// pre-wake row, so the bell would undercount still-actionable suggestions
  /// until consolidation; and a second flush appending to the same set reuses
  /// its id as the `idSeed`, so once the user has opened or dismissed the
  /// first row, `upsertNotification` preserves `seenAt`/`deletedAt` and the
  /// later suggestions could never raise the badge. One alert per wake, on the
  /// consolidated set, keeps both properties intact — the card itself still
  /// updates live, which is what the incremental flush is for.
  ///
  Future<void> notifyTaskNeedsAttention(ChangeSetEntity entity) async {
    // Count only the items the user actually needs to act on; previously
    // confirmed/rejected/retracted items don't warrant a fresh alert.
    final pendingCount = entity.items
        .where((i) => i.status == ChangeItemStatus.pending)
        .length;
    if (pendingCount == 0) return;

    if (!getIt.isRegistered<NotificationRepository>()) return;
    if (!getIt.isRegistered<JournalDb>()) return;

    try {
      final task = await getIt<JournalDb>().journalEntityById(taskId);
      final taskTitle = task is Task ? task.data.title : null;
      // No BuildContext here — the builder runs from agent wake. Pull the
      // current platform locale and resolve a synchronous AppLocalizations
      // instance so the inbox row honors the user's language.
      final messages = lookupAppLocalizations(
        ui.PlatformDispatcher.instance.locale,
      );
      final body = taskTitle == null || taskTitle.trim().isEmpty
          ? messages.notificationSuggestionAttentionBodyFallback
          : taskTitle;
      await getIt<NotificationRepository>().createTaskSuggestion(
        linkedTaskId: taskId,
        suggestionCount: pendingCount,
        title: messages.notificationSuggestionAttentionTitle(pendingCount),
        body: body,
        category: task is Task ? task.meta.categoryId : null,
        idSeed: entity.id,
      );
    } catch (e, st) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'Failed to fire change-set notification for task '
            '${DomainLogger.sanitizeId(taskId)}',
        stackTrace: st,
        subDomain: 'ChangeSetBuilder',
      );
    }
  }

  Future<void> _recordSupersededRunningTimerRetractions(
    AgentSyncService syncService,
    List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})> matches,
  ) async {
    if (matches.isEmpty) return;

    final now = clock.now();
    for (final match in matches) {
      final decision =
          AgentDomainEntity.changeDecision(
                id: _uuid.v4(),
                agentId: agentId,
                changeSetId: match.changeSet.id,
                itemIndex: match.itemIndex,
                toolName: match.item.toolName,
                verdict: ChangeDecisionVerdict.retracted,
                actor: DecisionActor.agent,
                taskId: taskId,
                retractionReason:
                    'Superseded by a newer running timer update proposal.',
                humanSummary: match.item.humanSummary,
                args: match.item.args,
                createdAt: now,
                vectorClock: const VectorClock({}),
              )
              as ChangeDecisionEntity;
      await syncService.upsertEntity(decision);
    }
  }

  /// Adds a `create_follow_up_task` item with a deterministic placeholder ID
  /// and returns the placeholder so callers can reference it in subsequent
  /// `migrate_checklist_items` calls. Follow-up args are stored in canonical
  /// form so formatting-only repeats use the same fingerprint and are queued
  /// only once per wake.
  Future<String> addFollowUpTask({
    required Map<String, dynamic> args,
    required String humanSummary,
    String? groupId,
  }) async {
    final title = args['title'];
    final dueDate = args['dueDate'];
    final priority = args['priority'];
    final relation = args['relation'];
    // Canonicalize: trim whitespace, uppercase priority, lowercase relation
    // so trivial formatting differences don't produce different placeholders.
    final canonTitle = title is String ? title.trim() : '';
    final canonDueDate = dueDate is String ? dueDate.trim() : '';
    final canonPriority = priority is String
        ? priority.trim().toUpperCase()
        : '';
    final rawCanonRelation = relation is String
        ? relation.trim().toLowerCase()
        : '';
    // An explicit relates_to IS the omitted default (a plain link), so it
    // canonicalizes to absence — both spellings must share one placeholder
    // and fingerprint or they would queue as two separate follow-ups.
    final canonRelation = rawCanonRelation == 'relates_to'
        ? ''
        : rawCanonRelation;
    // The relation joins the key only when present, so proposals without one
    // keep their pre-relation placeholder and still dedup across wakes
    // against pending items queued before the parameter existed.
    final placeholderId = deterministicPlaceholder(
      taskId,
      '$canonTitle|$canonDueDate|$canonPriority'
      '${canonRelation.isEmpty ? '' : '|$canonRelation'}',
    );

    final enrichedArgs = Map<String, dynamic>.from(args);
    if (title is String) {
      enrichedArgs['title'] = canonTitle;
    }
    if (dueDate is String) {
      if (canonDueDate.isEmpty) {
        enrichedArgs.remove('dueDate');
      } else {
        enrichedArgs['dueDate'] = canonDueDate;
      }
    }
    if (priority is String) {
      if (canonPriority.isEmpty) {
        enrichedArgs.remove('priority');
      } else {
        enrichedArgs['priority'] = canonPriority;
      }
    }
    if (relation is String) {
      if (canonRelation.isEmpty) {
        enrichedArgs.remove('relation');
      } else {
        enrichedArgs['relation'] = canonRelation;
      }
    }
    enrichedArgs['_placeholderTaskId'] = placeholderId;

    final fingerprint = ChangeItem.fingerprintFromParts(
      TaskAgentToolNames.createFollowUpTask,
      enrichedArgs,
    );
    if (_items.any((item) => ChangeItem.fingerprint(item) == fingerprint)) {
      return placeholderId;
    }

    _items.add(
      ChangeItem(
        toolName: TaskAgentToolNames.createFollowUpTask,
        args: enrichedArgs,
        humanSummary: humanSummary,
        groupId: groupId ?? placeholderId,
      ),
    );

    return placeholderId;
  }

  /// Returns the `_placeholderTaskId` from the most recently added
  /// `create_follow_up_task` item, or `null` if none exists.
  ///
  /// Used by the strategy to override the LLM's `targetTaskId` in
  /// `migrate_checklist_items` calls — the LLM may hallucinate a different
  /// string than the placeholder we returned.
  String? get followUpPlaceholderId {
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (item.toolName == TaskAgentToolNames.createFollowUpTask) {
        final pid = item.args['_placeholderTaskId'];
        if (pid is String) return pid;
      }
    }
    return null;
  }

  /// Generates a deterministic placeholder UUID for a follow-up task.
  ///
  /// Uses UUID v5 seeded from the source task ID and a distinguishing key
  /// (typically `title|dueDate|priority`) so that identical split proposals
  /// across wakes produce the same placeholder, preserving cross-wake dedup
  /// via [ChangeItem.fingerprint].
  static String deterministicPlaceholder(
    String sourceTaskId,
    String distinguishingKey,
  ) {
    return _uuid.v5(
      Namespace.url.value,
      'follow-up:$sourceTaskId:$distinguishingKey',
    );
  }
}
