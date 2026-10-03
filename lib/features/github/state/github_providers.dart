import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/distinct_pull_requests.dart';
import 'package:lotti/features/github/domain/pull_request_order.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';

/// One client for the process: its ETag cache and its rate-limit block are
/// per device, not per screen.
final gitHubClientProvider = Provider<GitHubClient>((ref) {
  final client = GitHubClient();
  ref.onDispose(client.close);
  return client;
}, name: 'gitHubClientProvider');

/// The token store of the active profile.
final gitHubTokenStorageProvider = Provider<GitHubTokenStorage>(
  (ref) => GitHubTokenStorage(
    getIt<SecureStorage>(),
    namespace: ref.watch(profileContextProvider).profile.id,
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

final pullRequestServiceProvider = Provider<PullRequestService>(
  (ref) => PullRequestService(
    client: ref.watch(gitHubClientProvider),
    tokenStorage: ref.watch(gitHubTokenStorageProvider),
    repository: ref.watch(pullRequestRepositoryProvider),
  ),
  name: 'pullRequestServiceProvider',
);

/// The live pull requests linked from a task, one per pull request
/// ([distinctPullRequests]), by number. Follows the task's links and every
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

/// The GitHub login whose token this device holds, or null.
final gitHubAccountControllerProvider =
    AsyncNotifierProvider<GitHubAccountController, String?>(
      GitHubAccountController.new,
      name: 'gitHubAccountControllerProvider',
    );

class GitHubAccountController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final storage = ref.watch(gitHubTokenStorageProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return null;
    return storage.readLogin();
  }

  /// Checks [token] with GitHub and stores it only if GitHub accepts it.
  /// Returns why it was refused, or null once it is stored.
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
      return null;
    } on GitHubException catch (e) {
      return e.kind;
    }
  }

  Future<void> disconnect() async {
    await ref.read(gitHubTokenStorageProvider).clear();
    state = const AsyncData(null);
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
