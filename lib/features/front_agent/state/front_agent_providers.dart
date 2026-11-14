import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/ensure_link.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/front_agent/model/front_live_answer.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/runtime/front_runtime_maintenance.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_door_walker.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/features/front_agent/service/front_owner_titles.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_model_resolution.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/journal/create/create_entry.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/device_region.dart';

/// The routing index over the journal and the agent store.
final frontRoutingIndexBuilderProvider = Provider<FrontRoutingIndexBuilder>(
  (ref) => FrontRoutingIndexBuilder(
    journalDb: ref.watch(journalDbProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
    // A host without a full-text index simply has no corpus match.
    fts5Db: ref.watch(fts5DbProvider),
    firstDayOfWeekIndex: () => ref.read(firstDayOfWeekIndexProvider.future),
    githubLogin: () => ref.read(gitHubTokenStorageProvider).readLogin(),
    pullRequestRepository: ref.watch(pullRequestRepositoryProvider),
  ),
  name: 'frontRoutingIndexBuilderProvider',
);

/// One routing turn per wake.
/// Her answer while a turn is still writing it (see [FrontLiveAnswer]).
final frontLiveAnswerProvider =
    NotifierProvider<FrontLiveAnswerNotifier, FrontLiveAnswer?>(
      FrontLiveAnswerNotifier.new,
      name: 'frontLiveAnswerProvider',
    );

class FrontLiveAnswerNotifier extends Notifier<FrontLiveAnswer?> {
  @override
  FrontLiveAnswer? build() => null;

  // Set from the running turn, as her message streams.
  // ignore: use_setters_to_change_properties
  void show(FrontLiveAnswer? answer) => state = answer;
}

final frontAgentWorkflowProvider = Provider<FrontAgentWorkflow>(
  (ref) => FrontAgentWorkflow(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    indexBuilder: ref.watch(frontRoutingIndexBuilderProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    // Read at each wake, so a sass changed since speaks from the next turn.
    sass: () => ref.read(companionCustomizationProvider).sass,
    onLiveAnswer: (answer) =>
        ref.read(frontLiveAnswerProvider.notifier).show(answer),
  ),
  name: 'frontAgentWorkflowProvider',
);

/// The one front agent, created on first use.
final frontAgentServiceProvider = Provider<FrontAgentService>(
  (ref) => FrontAgentService(
    agentService: ref.watch(agentServiceProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'frontAgentServiceProvider',
);

/// Which turns are still unanswered.
final frontChatHistoryServiceProvider = Provider<FrontChatHistoryService>(
  (ref) => FrontChatHistoryService(
    repository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontChatHistoryServiceProvider',
);

/// Durable user-authored turns (the goal-chat pattern, with recovery).
final frontChatServiceProvider = Provider<FrontChatService>(
  (ref) => FrontChatService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    notifications: ref.watch(updateNotificationsProvider),
    historyService: ref.watch(frontChatHistoryServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontChatServiceProvider',
);

/// The front agent's contribution to `agentRuntimeMaintenanceProvider`:
/// the recovery of an unanswered turn, on every device, every pass.
final frontRuntimeMaintenanceProvider = Provider<FrontRuntimeMaintenance>(
  (ref) => FrontRuntimeMaintenance(
    chatService: ref.watch(frontChatServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontRuntimeMaintenanceProvider',
);

/// The front agent's contribution to `agentResolvedSetupResolversProvider`:
/// its own setup, never a template's and never a category's.
///
/// Without a setup of her own she falls back to the Settings default
/// profile, so a change of that default resolves her again — her voice too,
/// which is that profile's read-aloud model.
Future<ResolvedAgentSetup?> resolveFrontAgentSetup(
  Ref ref,
  String agentId,
) async {
  final identity = await ref.watch(agentRepositoryProvider).getEntity(agentId);
  if (identity is! AgentIdentityEntity) return null;
  ref.watch(
    defaultInferenceProfileControllerProvider.select((value) => value.value),
  );
  final resolved = await resolveFrontAgentModel(
    agentIdentity: identity,
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
  return resolved?.setup;
}

/// Owner titles for the door records.
final frontOwnerTitlesProvider = Provider<FrontOwnerTitles>(
  (ref) => FrontOwnerTitles(
    journalDb: ref.watch(journalDbProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontOwnerTitlesProvider',
);

/// The door walker: the query pipeline for a task or project question, a
/// goal's or person's own chat for theirs.
final frontDoorWalkerProvider = Provider<FrontDoorWalker>(
  (ref) => FrontDoorWalker(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    queryBuilderFactory: ref.watch(queryBuilderFactoryProvider),
    taskAgentFor: ref.watch(taskAgentServiceProvider).getTaskAgentForTask,
    projectAgentFor: ref
        .watch(projectAgentServiceProvider)
        .getProjectAgentForProject,
    goalChat: ref.watch(goalChatServiceProvider),
    personChat: ref.watch(relationshipChatServiceProvider),
    ownerTitles: ref.watch(frontOwnerTitlesProvider),
    configFlag: ref.watch(journalDbProvider).getConfigFlag,
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontDoorWalkerProvider',
);

/// What the user's tap under a door does: the entry, the task or the note,
/// written through the persistence logic under the id the door names —
/// `createDbEntity` never overwrites an existing id, so a tap retried after
/// an interrupted write finds its entry already there.
final frontFilingServiceProvider = Provider<FrontFilingService>(
  (ref) => FrontFilingService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    notifications: ref.watch(updateNotificationsProvider),
    writeTextEntry: (text, {required id, linkedId, categoryId}) =>
        writeFrontTextEntry(
          ref.read(persistenceLogicProvider),
          ref.read(journalDbProvider),
          text,
          id: id,
          linkedId: linkedId,
          categoryId: categoryId,
        ),
    makeTask: ref.watch(frontTaskMakerProvider),
    makeEvent: (title, {required id}) => writeFrontEvent(
      ref.read(persistenceLogicProvider),
      ref.read(journalDbProvider),
      title,
      id: id,
    ),
    deleteEntry: (entryId) async {
      // A task taken back stops the timer a dictated start ran on it, and
      // takes its copy of the words along, so a re-make files no second
      // one. Its timer entry stays: logged time outlives the task, as on
      // any task deleted. For a note or a filed entry no such copy exists.
      final time = ref.read(timeServiceProvider);
      if (time.linkedFrom?.meta.id == entryId) await time.stop();
      final journal = ref.read(journalRepositoryProvider);
      final deleted = await journal.deleteJournalEntity(entryId);
      if (deleted) await journal.deleteJournalEntity(frontTaskWordsId(entryId));
      return deleted;
    },
    startExtra: ref.watch(frontTaskExtraStarterProvider),
    // Asked of the resolver itself, not through the card's provider: the
    // tap must get its answer whether or not anything is watching.
    canDrawCover: (categoryId) => frontCoverArtAvailable(
      ref.read(profileAutomationResolverProvider),
      categoryId,
    ),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontFilingServiceProvider',
);

/// Whether cover art can be drawn for a task made in a category, by its id
/// (none for a task filed in no category): a profile the run
/// can reach names an image-generation model — the category's default
/// profile, or the device's Settings default, which the run falls back to.
///
/// What the setup's cover chip is offered on, so it never asks for a cover
/// nothing could draw. The task's own profile is only known once the task
/// exists; these two are what it resolves from.
final FutureProviderFamily<bool, String?> frontCoverArtAvailableProvider =
    FutureProvider.autoDispose.family<bool, String?>(
      (ref, categoryId) => frontCoverArtAvailable(
        ref.watch(profileAutomationResolverProvider),
        categoryId,
      ),
      name: 'frontCoverArtAvailableProvider',
    );

/// The rule behind [frontCoverArtAvailableProvider], asked of [resolver]:
/// the category's default profile names an image-generation model, or the
/// Settings default does. One rule for the chip that offers a cover and for
/// the filing that asks for one.
Future<bool> frontCoverArtAvailable(
  ProfileAutomationResolver resolver,
  String? categoryId,
) async {
  if (categoryId != null) {
    final ofCategory = await resolver.resolveForCategory(categoryId);
    if (ofCategory?.imageGenerationProvider != null) return true;
  }
  final fallback = await resolver.resolveDefaultProfile();
  return fallback?.imageGenerationProvider != null;
}

/// The built-in skill that generates [extra].
String frontTaskExtraSkillId(FrontTaskExtra extra) => switch (extra) {
  FrontTaskExtra.coverArt => skillImageGenId,
  FrontTaskExtra.codingPrompt => skillPromptGenId,
};

/// How cover art or a coding prompt is started for a task made from the
/// user's words: the skill the AI popup runs, on the copy of the words filed
/// under the task (`frontTaskWordsId`) — typed or dictated, it is a text
/// entry, so no recording is needed — with the task as its context.
///
/// Not awaited: a generation outlives the tap by a minute or more, and the
/// trigger keeps itself alive, catches its own failures and reports them on
/// the entry, where the task page shows them. Whatever still escapes it is
/// dropped here rather than failing a task that is already made.
final frontTaskExtraStarterProvider = Provider<FrontTaskExtraStarter>(
  (ref) => (extra, {required taskId}) {
    ref
        .read(
          triggerSkillProvider((
            entityId: frontTaskWordsId(taskId),
            skillId: frontTaskExtraSkillId(extra),
            linkedTaskId: taskId,
            referenceImages: null,
            overrideModelId: null,
            geminiThinkingMode: null,
          )).future,
        )
        .ignore();
  },
  name: 'frontTaskExtraStarterProvider',
);

/// An event titled [title] under [id], tentative and dated now, as the
/// Events page's own create starts one.
///
/// The write's own verdict decides, as for a text entry: `true` is the new
/// event; `false` means a row under [id] already exists — the retry case —
/// and that event is returned when it is there and not deleted; `null`, or a
/// rejected write with no event behind it, is nothing stored.
Future<JournalEvent?> writeFrontEvent(
  PersistenceLogic persistence,
  JournalDb journalDb,
  String title, {
  required String id,
}) async {
  final now = clock.now();
  final event = JournalEvent(
    meta: await persistence.createMetadata(
      id: id,
      dateFrom: now,
      dateTo: now,
      starred: true,
    ),
    data: EventData(title: title, stars: 0, status: EventStatus.tentative),
    entryText: const EntryText(plainText: ''),
  );
  final saved = await persistence.createDbEntity(event);
  final written = (saved ?? false) ? event : await _existing(journalDb, id);
  return written is JournalEvent ? written : null;
}

/// A text entry with [text] under [id], linked under [linkedId] when given.
///
/// The write's own verdict decides: `true` is the new entry; `false` means a
/// row under [id] already exists — the retry case — and that row is
/// returned when it is there and not deleted; `null`, or a rejected write
/// with no row behind it, is nothing stored.
///
/// Under a task, the entry counts only once its link is live: the task
/// agent reads its entries through the link, so an entry without one is not
/// filed. A missing link — the link write refused or lost after the entry
/// landed — is written once more; still missing, nothing is filed.
Future<JournalEntity?> writeFrontTextEntry(
  PersistenceLogic persistence,
  JournalDb journalDb,
  String text, {
  required String id,
  String? linkedId,
  String? categoryId,
  DateTime? started,
}) async {
  final now = clock.now();
  final entry = JournalEntity.journalEntry(
    meta: await persistence.createMetadata(
      id: id,
      dateFrom: started ?? now,
      dateTo: now,
      categoryId: categoryId,
    ),
    entryText: EntryText(plainText: text),
  );
  final saved = await persistence.createDbEntity(entry, linkedId: linkedId);
  final written = (saved ?? false) ? entry : await _existing(journalDb, id);
  if (written == null || linkedId == null) return written;
  if (await _linked(journalDb, linkedId, id)) return written;
  await persistence.createLink(fromId: linkedId, toId: id);
  return await _linked(journalDb, linkedId, id) ? written : null;
}

/// Whether a live link runs from [fromId] to [toId].
Future<bool> _linked(JournalDb journalDb, String fromId, String toId) async =>
    (await journalDb.linksBetween(
      fromId,
      toId,
    )).any((link) => link.deletedAt == null);

/// How a task made from the user's words is written: [makeFrontTask] over
/// the app's persistence, timer and task-agent service.
final frontTaskMakerProvider = Provider<FrontTaskMaker>(
  (ref) =>
      (draft, {required id, required words}) => makeFrontTask(
        ref.read(persistenceLogicProvider),
        ref.read(journalDbProvider),
        draft,
        id: id,
        words: words,
        // Both only act on the timer as it is: a retry asks again, and a
        // timer already running on the entry is not started twice.
        startTimer: (timer, task) async {
          final time = ref.read(timeServiceProvider);
          if (time.getCurrent()?.meta.id == timer.meta.id) return;
          await time.start(timer, task);
        },
        stopTimer: (timerId) async {
          final time = ref.read(timeServiceProvider);
          if (time.getCurrent()?.meta.id == timerId) await time.stop();
        },
        // Read on use: only a follow-up needs the project repository.
        inheritProject: ({required sourceTaskId, required newTaskId}) => ref
            .read(projectRepositoryProvider)
            .inheritProjectFromTask(
              sourceTaskId: sourceTaskId,
              newTaskId: newTaskId,
            ),
        domainLogger: ref.read(domainLoggerProvider),
        assignAgent: (task) => autoAssignCategoryAgentWith(
          ref.read(taskAgentServiceProvider),
          task,
          domainLogger: ref.read(domainLoggerProvider),
        ),
      ),
  name: 'frontTaskMakerProvider',
);

/// [existing] — the task a retry found already made under its id — as
/// [draft] sets it up: a create whose door record failed to follow may be
/// retried with other choices, and the task takes the status, priority and
/// due day the user last set, not the first. Unchanged when they agree;
/// null when the update did not go through, so the retry fails rather than
/// reporting a task made as the user did not set it up.
Future<Task?> _asSetUp(
  PersistenceLogic persistence,
  Task existing,
  FrontTaskDraft draft,
) async {
  final status = taskStatusFromString(draft.status.dbStatus);
  final priority = draft.priority ?? TaskPriority.p2Medium;
  final data = existing.data;
  if (data.status.toDbString == status.toDbString &&
      data.priority == priority &&
      data.due == draft.due) {
    return existing;
  }
  final updated = await persistence.updateTask(
    journalEntityId: existing.meta.id,
    change: (stored) =>
        stored.withStatus(status).copyWith(priority: priority, due: draft.due),
  );
  return updated;
}

/// The task [draft] describes, under [id]: its title, instructions as the
/// body, category, priority, due day and estimate — what the agent fills
/// from the words; the rest is the user's on the task page.
///
/// A follow-up — a draft naming the task it follows — takes that task's
/// category when the words named none, so its category's agent is the one
/// assigned, and is filed under that task's project by [inheritProject]
/// (none when the task has none, or when a named category differs from the
/// project's). A failed project link is reported to [domainLogger] and the
/// task stands without one.
///
/// Once written, the user's [words] are filed under it as a linked text
/// entry — where the task came from, and what its agent reads — a follow-up
/// is linked `followsUp` to its task, the task is made in the draft's
/// [FrontTaskDraft.status], one that says when the work began also runs a
/// timer from that moment ([startTimer], on a linked entry starting then),
/// and [assignAgent] hands it the category's
/// default agent, last, so the agent's first wake sees all of it.
///
/// The creation path answers null for a rejected write, which for a
/// deterministic id means the task is already there — the retry case — so
/// that task is returned with nothing added twice, and null when nothing is
/// stored. A retry brings it in line with how it is set up: its status,
/// priority and due day, then its dictated timer — asked to run when the task
/// is in progress ([startTimer], a no-op for the one already running), asked
/// to stop otherwise ([stopTimer], only if it is the one running) — from the
/// timer as it is, not from the status before, so a retry after a timer step
/// that failed asks again.
///
/// The timer is best effort: a timer entry that could not be written is
/// reported to [domainLogger], and the task stands without a running timer
/// the user can start from its page.
Future<Task?> makeFrontTask(
  PersistenceLogic persistence,
  JournalDb journalDb,
  FrontTaskDraft draft, {
  required String id,
  required String words,
  required Future<void> Function(JournalEntity timer, JournalEntity task)
  startTimer,
  required Future<void> Function(String timerId) stopTimer,
  required Future<bool> Function({
    required String sourceTaskId,
    required String newTaskId,
  })
  inheritProject,
  required DomainLogger domainLogger,
  required Future<void> Function(Task task) assignAgent,
}) async {
  final now = clock.now();
  final started = draft.startedAt;
  final followed = switch (draft.followsUpTaskId) {
    final id? => switch (await _existing(journalDb, id)) {
      final Task task => task,
      _ => null,
    },
    null => null,
  };
  final categoryId = draft.categoryId ?? followed?.meta.categoryId;
  // The dictated start, if any: a timer on a linked entry starting then.
  Future<void> runTimer(Task task) async {
    if (started == null) return;
    final timer = await writeFrontTextEntry(
      persistence,
      journalDb,
      '',
      id: frontTaskTimerId(id),
      linkedId: id,
      categoryId: categoryId,
      started: started.isAfter(now) ? now : started,
    );
    if (timer == null) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        StateError('The timer entry was not written.'),
        subDomain: 'makeFrontTask',
        message: 'No dictated timer for ${DomainLogger.sanitizeId(id)}',
      );
      return;
    }
    await startTimer(timer, task);
  }

  final task = await persistence.createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(draft.status.dbStatus),
      title: draft.title,
      statusHistory: [],
      dateTo: now,
      dateFrom: now,
      estimate: draft.estimate ?? Duration.zero,
      priority: draft.priority ?? TaskPriority.p2Medium,
      due: draft.due,
    ),
    entryText: EntryText(plainText: draft.instructions ?? ''),
    categoryId: categoryId,
    id: id,
  );
  if (task == null) {
    final existing = await _existing(journalDb, id);
    if (existing is! Task) return null;
    final setUp = await _asSetUp(persistence, existing, draft);
    if (setUp == null) return null;
    if (draft.status == FrontTaskStart.inProgress) {
      await runTimer(setUp);
    } else {
      await stopTimer(frontTaskTimerId(id));
    }
    return setUp;
  }
  // shortcut: a crash between the task and these leaves a bare task the
  // user fills on its page; making them retryable needs per-step records.
  await writeFrontTextEntry(
    persistence,
    journalDb,
    words,
    id: frontTaskWordsId(id),
    linkedId: id,
    categoryId: categoryId,
  );
  if (followed != null) {
    await ensureLink(
      persistenceLogic: persistence,
      journalDb: journalDb,
      fromId: id,
      toId: followed.meta.id,
      linkType: EntryLinkType.followsUp,
    );
    try {
      await inheritProject(sourceTaskId: followed.meta.id, newTaskId: id);
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'makeFrontTask',
        message:
            'Failed to inherit project from '
            '${DomainLogger.sanitizeId(followed.meta.id)} for '
            '${DomainLogger.sanitizeId(id)}',
      );
    }
  }
  await runTimer(task);
  await assignAgent(task);
  return task;
}

/// The row under [id] when it is there and not deleted.
Future<JournalEntity?> _existing(JournalDb journalDb, String id) async {
  final existing = await journalDb.journalEntityById(id);
  return existing != null && existing.meta.deletedAt == null ? existing : null;
}

/// The front agent's contribution to `agentWakeRunnersProvider` — merged in
/// `app_bootstrap.dart`, never left to the silent task-agent fallback in
/// `agent_wiring.dart` (pinned by `test/app_bootstrap_test.dart`).
///
/// Only a chat token enters the model: the front agent has no scheduled or
/// subscription wakes, so any other token is a no-op success. A turn that
/// is already routed, asked about or replied to — a recovery wake arriving
/// after the author's own run — is not routed again (the goal runner's
/// rule); its doors are still walked, which the claims make idempotent, so a
/// walk that died with its device is finished here.
final frontAgentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => <String, AgentWakeRunner>{
    AgentKinds.frontAgent:
        ({
          required agentIdentity,
          required runKey,
          required triggerTokens,
          required threadId,
        }) async {
          final messageId = frontChatMessageIdFromTriggerTokens(triggerTokens);
          if (messageId == null) return const WakeResult(success: true);
          final unrouted = await ref
              .read(frontChatHistoryServiceProvider)
              .unroutedMessageIds();
          var result = const WakeResult(success: true);
          if (unrouted.contains(messageId)) {
            result = await ref
                .read(frontAgentWorkflowProvider)
                .executeUserMessage(
                  agentIdentity: agentIdentity,
                  runKey: runKey,
                  triggerTokens: triggerTokens,
                  threadId: threadId,
                  messageId: messageId,
                );
            if (!result.success) return result;
          }
          await ref.read(frontDoorWalkerProvider).walk(messageId);
          return result;
        },
  },
  name: 'frontAgentWakeRunnersProvider',
);
