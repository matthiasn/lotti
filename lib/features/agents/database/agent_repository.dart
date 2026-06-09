import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

part 'agent_attention_projection.dart';
part 'agent_proposal_ledger.dart';
part 'agent_repo_core.dart';
part 'agent_repo_queries.dart';
part 'agent_repo_evolution.dart';
part 'agent_repo_links.dart';

const _overFetchMultiplier = 5;

bool _affectsAttentionClaimProjection(AgentDomainEntity entity) {
  return entity is AttentionRequestEntity ||
      entity is AttentionClaimDispositionEntity;
}

bool _affectsStandingAgreementProjection(AgentDomainEntity entity) {
  return entity is StandingAgreementEntity;
}

const int _sqliteInClauseChunkSize = 900;

Iterable<List<T>> _sqliteInClauseChunks<T>(Iterable<T> values) sync* {
  final valueList = values.toSet().toList(growable: false);
  for (
    var start = 0;
    start < valueList.length;
    start += _sqliteInClauseChunkSize
  ) {
    final end = start + _sqliteInClauseChunkSize > valueList.length
        ? valueList.length
        : start + _sqliteInClauseChunkSize;
    yield valueList.sublist(start, end);
  }
}

class AttentionPlanningInputs {
  const AttentionPlanningInputs({
    required this.claims,
    required this.standingAgreements,
  });

  const AttentionPlanningInputs.empty()
    : claims = const [],
      standingAgreements = const [];

  final List<AttentionRequestEntity> claims;
  final List<StandingAgreementEntity> standingAgreements;

  bool get isEmpty => claims.isEmpty && standingAgreements.isEmpty;
}

/// Typed CRUD repository wrapping [AgentDatabase] and [AgentDbConversions].
///
/// All entity reads go through [AgentDbConversions.fromEntityRow] and all
/// entity writes go through [AgentDbConversions.toEntityCompanion]. Link reads
/// go through [AgentDbConversions.fromLinkRow] and link writes go through
/// [AgentDbConversions.toLinkCompanion].
///
/// Wake-run log and saga log rows are plain Drift data classes and are read
/// and written directly without an intermediate domain conversion.

abstract class _AgentRepositoryBase {
  _AgentRepositoryBase(this._db, {DomainLogger? domainLogger})
    : _domainLogger = domainLogger;

  final AgentDatabase _db;
  final DomainLogger? _domainLogger;

  // Cross-mixin contracts implemented by the method-group mixins.
  Future<AgentDomainEntity?> getEntity(String id);

  Future<Map<String, AgentDomainEntity>> getEntitiesByIds(
    Iterable<String> ids,
  );

  Future<List<AttentionRequestEntity>> getAttentionClaimsForTargetImpl({
    required String targetKind,
    required String targetId,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 50,
  });

  Future<List<AttentionRequestEntity>> getAttentionClaimsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 200,
  });

  Future<AttentionPlanningInputs> getAttentionPlanningInputsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> claimStatuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    Set<StandingAgreementStatus> agreementStatuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? agreementScopes,
    int claimLimit = 200,
    int agreementLimit = 200,
  });

  Future<ProposalLedger> getProposalLedgerImpl(
    String agentId, {
    required String taskId,
    int changeSetFetchLimit = 200,
    int resolvedLimit = 50,
  });

  Future<List<StandingAgreementEntity>> getStandingAgreementsForWindowImpl({
    required DateTime start,
    required DateTime end,
    Set<StandingAgreementStatus> statuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? scopes,
    int limit = 200,
  });

  Future<void> rebuildAttentionClaimProjectionImpl();

  Future<void> rebuildStandingAgreementProjectionImpl();

  Future<List<model.AgentLink>> getLinksTo(
    String toId, {
    String? type,
  });

  Future<Map<String, List<model.AgentLink>>> getLinksToMultiple(
    List<String> toIds, {
    required String type,
  });

  Future<List<AgentDomainEntity>> _latestEntitiesByAgentIds({
    required Iterable<String> agentIds,
    required String type,
    String? subtype,
  });

  Future<void> _refreshAttentionClaimProjectionForEntity(
    AgentDomainEntity entity,
  );

  Future<void> _refreshStandingAgreementProjectionForEntity(
    AgentDomainEntity entity,
  );
}

class AgentRepository extends _AgentRepositoryBase
    with
        _AgentAttentionProjection,
        _AgentProposalLedger,
        _AgentRepoCore,
        _AgentRepoQueries,
        _AgentRepoEvolution,
        _AgentRepoLinks {
  AgentRepository(AgentDatabase db, {DomainLogger? domainLogger})
    : super(db, domainLogger: domainLogger);

  /// Test-only seam for `_sqliteInClauseChunks` — the pure dedup-and-chunk
  /// iterator that guards every batched `IN (...)` query against SQLite's
  /// `SQLITE_MAX_VARIABLE_NUMBER` cap. The chunk size is exposed alongside so
  /// property tests can assert the no-chunk-exceeds-the-limit invariant
  /// without hard-coding the constant.
  @visibleForTesting
  static const int debugInClauseChunkSize = _sqliteInClauseChunkSize;

  /// Test-only seam for `_sqliteInClauseChunks`.
  @visibleForTesting
  static Iterable<List<T>> debugSqliteInClauseChunks<T>(Iterable<T> values) =>
      _sqliteInClauseChunks(values);
}
