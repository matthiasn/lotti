import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_order.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/distinct_pull_requests.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/repository/github_account_sync.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:lotti/features/github/service/pull_request_summary_tool.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/secure_storage.dart';
import 'package:openai_dart/openai_dart.dart' show ReasoningEffort;

/// One client for the process: its ETag cache and its rate-limit block are
/// per device, not per screen.
final gitHubClientProvider = Provider<GitHubClient>((ref) {
  final client = GitHubClient();
  ref.onDispose(client.close);
  return client;
}, name: 'gitHubClientProvider');

/// The token store of the active profile.
final gitHubTokenStorageProvider = Provider<GitHubTokenStorage>(
  (ref) => gitHubTokenStorageForProfile(
    getIt<SecureStorage>(),
    ref.watch(profileContextProvider),
  ),
  name: 'gitHubTokenStorageProvider',
);

final pullRequestRepositoryProvider = Provider<PullRequestRepository>(
  (ref) => PullRequestRepository(
    journalDb: ref.watch(journalDbProvider),
    persistenceLogic: getIt<PersistenceLogic>(),
    journalRepository: ref.watch(journalRepositoryProvider),
  ),
  name: 'pullRequestRepositoryProvider',
);

/// How many tokens one pull request summary may take: its two tiers, with
/// room for a little reasoning.
const pullRequestSummaryMaxTokens = 800;

/// Summarises pull requests with the task agent's model — automatically
/// where the task's category has automatic inference switched on, and
/// whenever the user asks.
final pullRequestSummarizerProvider = Provider<PullRequestSummarizer>((ref) {
  final summarizer = PullRequestSummarizer(
    repository: ref.watch(pullRequestRepositoryProvider),
    taskOf: (taskId) async {
      final db = ref.read(journalDbProvider);
      final task = await db.journalEntityById(taskId);
      final categoryId = task?.meta.categoryId;
      final category = categoryId == null
          ? null
          : await db.getCategoryById(categoryId);
      return (
        categoryId: categoryId,
        automaticInference:
            category?.automaticInferenceEnabledEffective ?? false,
        languageCode: task is Task ? task.data.languageCode : null,
      );
    },
    modelFor: (taskId) async {
      final profile = await ref
          .read(profileAutomationResolverProvider)
          .resolveForSubject(taskId);
      return profile == null
          ? null
          : (
              modelId: profile.thinkingModelId,
              provider: profile.thinkingProvider,
            );
    },
    generate:
        ({
          required prompt,
          required systemMessage,
          required model,
          required taskId,
          required categoryId,
          required manual,
        }) async {
          final answer = await ref
              .read(cloudInferenceRepositoryProvider)
              .generateToolCalls(
                prompt: prompt,
                systemMessage: systemMessage,
                model: model.modelId,
                provider: model.provider,
                temperature: 0.2,
                // Two tiers; a model that runs past them is cut, not billed
                // for pages. Reasoning stays minimal, so they fit.
                maxCompletionTokens: pullRequestSummaryMaxTokens,
                geminiThinkingMode: GeminiThinkingMode.minimal,
                reasoningEffort: ReasoningEffort.minimal,
                tools: const [pullRequestSummaryTool],
                toolChoice: pullRequestSummaryToolChoiceFor(model.modelId),
                attribution: OneShotGenerationAttribution(
                  workType: AiWorkType.textGeneration,
                  triggerType: manual
                      ? AiTriggerType.manual
                      : AiTriggerType.automatic,
                  categoryId: categoryId,
                  taskId: taskId,
                ),
              );
          return answer.toolCalls;
        },
    logger: ref.watch(domainLoggerProvider),
  );
  ref.onDispose(summarizer.dispose);
  return summarizer;
}, name: 'pullRequestSummarizerProvider');

final pullRequestServiceProvider = Provider<PullRequestService>(
  (ref) => PullRequestService(
    client: ref.watch(gitHubClientProvider),
    tokenStorage: ref.watch(gitHubTokenStorageProvider),
    repository: ref.watch(pullRequestRepositoryProvider),
    onTokenVerdict: (token, {required accepted}) => unawaited(
      ref
          .read(gitHubTokenStatusProvider.notifier)
          .observe(token, accepted: accepted),
    ),
    summarizer: ref.watch(pullRequestSummarizerProvider),
  ),
  name: 'pullRequestServiceProvider',
);

/// Refreshes and renders a task's pull requests for a task context.
final pullRequestContextServiceProvider = Provider<PullRequestContextService>((
  ref,
) {
  final tokens = ref.watch(gitHubTokenStorageProvider);
  return PullRequestContextService(
    repository: ref.watch(pullRequestRepositoryProvider),
    service: ref.watch(pullRequestServiceProvider),
    hasToken: tokens.hasToken,
  );
}, name: 'pullRequestContextServiceProvider');

/// What this device knows about its GitHub token.
enum GitHubTokenStatus {
  /// No token is stored.
  none,

  /// A token is stored, and GitHub has not rejected it since: it was checked
  /// when it was saved, and every call since either succeeded or said
  /// nothing about it.
  valid,

  /// GitHub answered a call with the stored token with 401 — it expired, or
  /// was revoked — or a token received from another device has not passed
  /// its check here. Until a call succeeds again or a token is connected or
  /// received anew.
  rejected,
}

/// The status of the stored GitHub token, without asking GitHub for it.
///
/// A held token is [GitHubTokenStatus.valid] once the account has accepted
/// it — `GET /user` when it was entered here, or the account's check of one
/// received from another device — until a call with it comes back 401
/// ([PullRequestService] reports each verdict). Opening a task costs no
/// extra request: the refresh of its stale pull requests is the check. A
/// 401 is kept in memory only, so after a restart the token is taken as
/// valid again until GitHub next says otherwise.
final gitHubTokenStatusProvider =
    AsyncNotifierProvider<GitHubTokenStatusController, GitHubTokenStatus>(
      GitHubTokenStatusController.new,
      name: 'gitHubTokenStatusProvider',
    );

class GitHubTokenStatusController extends AsyncNotifier<GitHubTokenStatus> {
  /// The token the status is about; a verdict on any other — one replaced
  /// while its call was in flight — is ignored.
  String? _token;

  /// Built again when a token is connected, disconnected or received from
  /// another device: all three announce `gitHubAccountNotification`. Not by
  /// following the account's value, which reconnecting the same account with
  /// a fresh token leaves as it was — that would keep a rejection of the old
  /// token.
  ///
  /// A held token is valid once the account accepts it: a token entered
  /// here was checked before it was stored, and one received from another
  /// device is checked by the account (`GET /user`) before it is shown as
  /// connected. Until that check succeeds — GitHub rejected it, or could not
  /// be asked — it is not offered for tracking.
  @override
  Future<GitHubTokenStatus> build() async {
    final changes = getIt<UpdateNotifications>().updateStream
        .where((ids) => ids.contains(gitHubAccountNotification))
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);

    final token = await ref.watch(gitHubTokenStorageProvider).readToken();
    _token = token;
    if (token == null || token.isEmpty) return GitHubTokenStatus.none;
    try {
      await ref.watch(gitHubAccountControllerProvider.future);
      return GitHubTokenStatus.valid;
    } on Object {
      return GitHubTokenStatus.rejected;
    }
  }

  /// Records what a call with [token] said: GitHub [accepted] it, or
  /// rejected it with a 401.
  ///
  /// Waits for the stored token to be read first. The first call is often
  /// made before anything watched the status — reading this notifier is
  /// what starts the read — and a verdict judged before the read finished
  /// would be dropped, leaving a revoked token offered as valid.
  Future<void> observe(String token, {required bool accepted}) async {
    try {
      await future;
    } on Object {
      return;
    }
    if (!ref.mounted || token != _token) return;
    final next = accepted
        ? GitHubTokenStatus.valid
        : GitHubTokenStatus.rejected;
    if (state.value != next) state = AsyncData(next);
  }
}

/// Whether this device may start tracking pull requests: it holds a GitHub
/// token that GitHub has not rejected. Gates what starts tracking — a
/// task's "Pull request tracking" action and a category's repository — and
/// never what is already linked: a task's pull requests stay on its card,
/// with their last known state, whatever becomes of the token.
final gitHubTrackingAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(gitHubTokenStatusProvider).value == GitHubTokenStatus.valid,
  name: 'gitHubTrackingAvailableProvider',
);

/// The live pull requests linked from a task, one per pull request
/// ([distinctPullRequests]), newest first. Follows the task's links and every
/// entry, so a refresh, a sync or an unlink shows at once.
final ProviderFamily<List<PullRequestEntry>, String> taskPullRequestsProvider =
    Provider.autoDispose.family<List<PullRequestEntry>, String>(
      (ref, taskId) => distinctPullRequests(
        ref
            .watch(resolvedOutgoingLinkedEntriesProvider(taskId))
            .whereType<PullRequestEntry>(),
      ),
      name: 'taskPullRequestsProvider',
    );

/// Whether task `taskId` shows its Pull requests section: once the user
/// turned pull request tracking on for it (`TaskData.tracksPullRequests`),
/// or while it has a pull request linked — so a task linked to one before
/// the opt-in existed shows it without a migration.
final ProviderFamily<bool, String> taskShowsPullRequestsProvider = Provider
    .autoDispose
    .family<bool, String>((ref, taskId) {
      final entry = ref.watch(entryControllerProvider(taskId)).value?.entry;
      final optedIn = entry is Task && entry.data.tracksPullRequests;
      return optedIn || ref.watch(taskPullRequestsProvider(taskId)).isNotEmpty;
    }, name: 'taskShowsPullRequestsProvider');

/// The GitHub repository a task works in: its category's, or null.
///
/// Read again from the database when the task changes (its category may have)
/// or any category does, saved here or synced in, so an open picker follows.
/// Not from the categories cache: it reloads after the same notification, and
/// a read racing that reload would see the old repository.
final StreamProviderFamily<GitHubRepository?, String>
taskGitHubRepositoryProvider = StreamProvider.autoDispose
    .family<GitHubRepository?, String>((ref, taskId) {
      final db = ref.watch(journalDbProvider);
      return notificationDrivenItemStream<GitHubRepository>(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {
          taskId,
          categoriesNotification,
          privateToggleNotification,
        },
        fetcher: () async {
          final task = await db.journalEntityById(taskId);
          final categoryId = task?.meta.categoryId;
          if (categoryId == null) return null;
          final repository = (await db.getCategoryById(
            categoryId,
          ))?.githubRepository;
          return repository == null ? null : parseGitHubRepository(repository);
        },
      );
    }, name: 'taskGitHubRepositoryProvider');

/// What the picker offers from [GitHubRepository]: its open pull requests
/// that no task holds.
final FutureProviderFamily<OpenPullRequestsResult, GitHubRepository>
openPullRequestsProvider = FutureProvider.autoDispose
    .family<OpenPullRequestsResult, GitHubRepository>(
      (ref, repository) =>
          ref.watch(pullRequestServiceProvider).openPullRequests(repository),
      name: 'openPullRequestsProvider',
    );

/// The size of the open pull requests of `repository`, by number — read
/// apart from [openPullRequestsProvider], so the picker lists them without
/// waiting, and without them if it cannot be read.
final FutureProviderFamily<Map<int, PullRequestSize>, GitHubRepository>
openPullRequestSizesProvider = FutureProvider.autoDispose
    .family<Map<int, PullRequestSize>, GitHubRepository>(
      (ref, repository) => ref
          .watch(pullRequestServiceProvider)
          .openPullRequestSizes(repository),
      name: 'openPullRequestSizesProvider',
    );

/// The summary of pull request entry `entryId`'s current content, or null
/// while none is written — kept current as the entry changes and as a
/// summary of it is stored, here or on another device.
final StreamProviderFamily<PullRequestSummary?, String>
pullRequestSummaryProvider = StreamProvider.autoDispose
    .family<PullRequestSummary?, String>((ref, entryId) async* {
      final repository = ref.watch(pullRequestRepositoryProvider);
      Future<PullRequestSummary?> read() async {
        final entry = await repository.liveEntry(entryId);
        final snapshot = entry?.data.snapshot;
        if (entry == null || snapshot == null) return null;
        return repository.summaryOf(
          entryId,
          pullRequestSummaryInput(entry.data.ref, snapshot),
        );
      }

      yield await read();
      await for (final ids
          in ref.watch(updateNotificationsProvider).updateStream) {
        if (ids.contains(entryId)) yield await read();
      }
    }, name: 'pullRequestSummaryProvider');

/// Why pull request entry `entryId` would not be summarised automatically
/// now — no category consent, no model, or a recent failure — or null when
/// its next refresh would ask for a summary. For telling the user why one
/// is missing; asks no model.
///
/// Kept current while watched: asked again when an attempt for the entry
/// ends, when the entry, a category or an agent changes, and when a
/// cool-down runs out. A change to the inference providers or models is
/// seen the next time the details open.
final StreamProviderFamily<PullRequestSummaryOutcome?, String>
pullRequestAutomaticSummaryBlockerProvider = StreamProvider.autoDispose
    .family<PullRequestSummaryOutcome?, String>((ref, entryId) {
      final summarizer = ref.watch(pullRequestSummarizerProvider);
      final blockers = StreamController<PullRequestSummaryOutcome?>();
      Timer? coolDownEnds;

      Future<void> read() async {
        final blocker = await summarizer.automaticBlocker(entryId);
        if (blockers.isClosed) return;
        blockers.add(blocker);
        coolDownEnds?.cancel();
        final ends = summarizer.coolDownEnds(entryId);
        if (ends != null) {
          coolDownEnds = Timer(ends.difference(clock.now()), read);
        }
      }

      final subscriptions = [
        summarizer.attempts.where((id) => id == entryId).listen((_) => read()),
        ref
            .watch(updateNotificationsProvider)
            .updateStream
            .where(
              (ids) =>
                  ids.contains(entryId) ||
                  ids.contains(categoriesNotification) ||
                  ids.contains(agentNotification),
            )
            .listen((_) => read()),
      ];
      ref.onDispose(() {
        coolDownEnds?.cancel();
        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
        unawaited(blockers.close());
      });
      unawaited(read());
      return blockers.stream;
    }, name: 'pullRequestAutomaticSummaryBlockerProvider');

/// The tasks that hold pull request [PullRequestRef.key], kept current as
/// pull request entries and links change — including those sync brings in,
/// which is how a double assignment from two devices comes to light.
final StreamProviderFamily<Set<String>, PullRequestRef>
pullRequestHoldersProvider = StreamProvider.autoDispose
    .family<Set<String>, PullRequestRef>((ref, pr) async* {
      final repository = ref.watch(pullRequestRepositoryProvider);
      Future<Set<String>> read() async =>
          (await repository.holdersOf([pr]))[pr.key] ?? const <String>{};
      yield await read();
      await for (final ids in getIt<UpdateNotifications>().updateStream) {
        if (ids.contains(pullRequestNotification) ||
            ids.contains(linkNotification)) {
          yield await read();
        }
      }
    }, name: 'pullRequestHoldersProvider');

/// The title of task `taskId` as the viewer may see it, for naming the
/// other task that holds a pull request — null while private mode hides it,
/// or once it is gone. Read like the task's linked tasks are, through the
/// private-filtered read, and again when the task or private mode changes.
///
/// On such a change the title is withdrawn at once, before the read: private
/// mode may just have been turned off, or the task made private, and a title
/// the viewer may no longer see must not stay on screen while the read is
/// pending.
final StreamProviderFamily<String?, String> pullRequestHolderTitleProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, taskId) async* {
      final journal = ref.watch(journalRepositoryProvider);
      Future<String?> read() async => (await journal.getJournalEntitiesByIds({
        taskId,
      })).whereType<Task>().firstOrNull?.data.title;
      yield await read();
      await for (final ids in getIt<UpdateNotifications>().updateStream) {
        if (ids.contains(privateToggleNotification) || ids.contains(taskId)) {
          yield null;
          yield await read();
        }
      }
    }, name: 'pullRequestHolderTitleProvider');

/// Sends this device's GitHub account to the user's other devices, and asks
/// sync to catch up. A world without sync — a guest or demo world — gets an
/// inert outbox and no catch-up.
final gitHubAccountSyncProvider = Provider<GitHubAccountSync>(
  (ref) => GitHubAccountSync(
    storage: ref.watch(gitHubTokenStorageProvider),
    enqueueOrThrow: (message) =>
        getIt<OutboxService>().enqueueMessageOrThrow(message),
    rescan:
        ref.watch(syncFeatureAvailableProvider) &&
            getIt.isRegistered<MatrixService>()
        ? () => getIt<MatrixService>().forceRescan()
        : null,
  ),
  name: 'gitHubAccountSyncProvider',
);

/// The GitHub login whose token this device holds, or null.
///
/// The token syncs between the user's devices. One that arrived from another
/// device is checked with GitHub (`GET /user`) before it is shown as
/// connected: until a check succeeds — GitHub rejected it, or could not be
/// asked yet (offline, rate limited) — the failure is the state, an error,
/// and "check my other devices" checks again.
///
/// Never retried on its own: a rejection is final until the user enters a
/// token or another one arrives, and asking GitHub again and again with a
/// revoked token would only spend the rate limit.
final gitHubAccountControllerProvider =
    AsyncNotifierProvider<GitHubAccountController, String?>(
      GitHubAccountController.new,
      name: 'gitHubAccountControllerProvider',
      retry: (_, _) => null,
    );

class GitHubAccountController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // A token connected, disconnected or received elsewhere: read again.
    final changes = getIt<UpdateNotifications>().updateStream
        .where((ids) => ids.contains(gitHubAccountNotification))
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);

    final storage = ref.watch(gitHubTokenStorageProvider);
    // A newer token can arrive while GitHub is checking one: the check marks
    // only the version it checked, and the newer one is then checked too.
    for (var attempt = 0; ; attempt++) {
      final record = await storage.read();
      if (record == null || !record.connected) return null;
      if (record.verified) return record.login;
      // Any failure is the answer until a check succeeds: a token GitHub
      // rejected, or one it could not be asked about yet, is not shown as
      // connected under the login it arrived with.
      final login = await ref
          .read(gitHubClientProvider)
          .fetchViewerLogin(record.token!);
      final marked = await storage.markVerified(
        token: record.token!,
        updatedAt: record.updatedAt,
        login: login,
      );
      if (marked || attempt >= 2) return marked ? login : null;
    }
  }

  /// Whether a change made here has not reached the outbox yet; it is sent
  /// again at the next start or the next change.
  Future<bool> changeOwed() async =>
      (await ref.read(gitHubTokenStorageProvider).read())?.owed ?? false;

  /// Checks [token] with GitHub, stores it only if GitHub accepts it, and
  /// sends it to the user's other devices. Returns why it was refused, or
  /// null once it is stored.
  Future<GitHubFailureKind?> connect(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return GitHubFailureKind.noToken;
    try {
      final login = await ref
          .read(gitHubClientProvider)
          .fetchViewerLogin(trimmed);
      await ref
          .read(gitHubTokenStorageProvider)
          .save(token: trimmed, login: login);
      state = AsyncData(login);
      _announce();
      await ref.read(gitHubAccountSyncProvider).flushOwed();
      return null;
    } on GitHubException catch (e) {
      return e.kind;
    }
  }

  /// Forgets the token here and on the user's other devices.
  Future<void> disconnect() async {
    await ref.read(gitHubTokenStorageProvider).clear();
    state = const AsyncData(null);
    _announce();
    await ref.read(gitHubAccountSyncProvider).flushOwed();
  }

  /// Tells whoever follows the account — the token status — that the token
  /// changed here, as sync does for one received from another device.
  void _announce() =>
      getIt<UpdateNotifications>().notify({gitHubAccountNotification});

  /// Sends the token held here to the user's other devices again — one
  /// connected before tokens synced, or that a device joining later missed.
  /// Returns whether the outbox took it, or null when there is none to send.
  Future<bool?> sendToOtherDevices() =>
      ref.read(gitHubAccountSyncProvider).resend();

  /// Asks sync to catch up, then reads the token again: on a device that
  /// has none, one sent from another device arrives this way.
  Future<void> checkOtherDevices() async {
    await ref.read(gitHubAccountSyncProvider).checkOtherDevices();
    ref.invalidateSelf();
    await future;
  }
}

/// What this device knows about refreshing one pull request entry. None of
/// it is synced: a failure is this device's, and an unchanged observation
/// is not written (see `shouldWritePullRequestObservation`).
class PullRequestRefreshState {
  const PullRequestRefreshState({
    this.refreshing = false,
    this.failure,
    this.observation,
  });

  final bool refreshing;

  /// Why the last refresh failed; cleared by the next success.
  final PullRequestRefreshFailed? failure;

  /// What the last successful refresh read, written or not.
  final PullRequestSnapshot? observation;

  /// The newer of [observation] and [stored], for display: both were true
  /// at their own stamps, so the newer one is the honest age to show.
  PullRequestSnapshot? latest(PullRequestSnapshot? stored) =>
      comparePullRequestObservations(observation, stored) > 0
      ? observation
      : stored;
}

final NotifierProviderFamily<
  PullRequestRefreshController,
  PullRequestRefreshState,
  String
>
pullRequestRefreshControllerProvider = NotifierProvider.autoDispose
    .family<PullRequestRefreshController, PullRequestRefreshState, String>(
      PullRequestRefreshController.new,
      name: 'pullRequestRefreshControllerProvider',
    );

class PullRequestRefreshController extends Notifier<PullRequestRefreshState> {
  PullRequestRefreshController(this._entryId);

  /// How old a snapshot may be before opening its task refreshes it.
  static const staleAfter = Duration(minutes: 5);

  final String _entryId;

  @override
  PullRequestRefreshState build() => const PullRequestRefreshState();

  /// Refreshes [entry] now, unless a refresh is already running.
  Future<void> refresh(PullRequestEntry entry) async {
    if (state.refreshing) return;
    assert(entry.id == _entryId, 'refresh of another entry');
    state = PullRequestRefreshState(
      refreshing: true,
      failure: state.failure,
      observation: state.observation,
    );
    final result = await ref.read(pullRequestServiceProvider).refresh(entry);
    if (!ref.mounted) return;
    state = switch (result) {
      PullRequestRefreshed(:final observation) => PullRequestRefreshState(
        observation: observation,
      ),
      final PullRequestRefreshFailed failure => PullRequestRefreshState(
        failure: failure,
        observation: state.observation,
      ),
    };
  }

  /// Refreshes [entry] when what it shows is older than [staleAfter] and
  /// nothing has been tried since this controller was created.
  Future<void> refreshIfStale(PullRequestEntry entry) async {
    if (state.refreshing || state.failure != null) return;
    final shown = state.latest(entry.data.snapshot);
    if (shown != null &&
        clock.now().difference(shown.observedAt) < staleAfter) {
      return;
    }
    await refresh(entry);
  }
}
