import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';

void main() {
  test('round-trips votes with digest-bound cascade trace references', () {
    final vote = _vote(
      voteId: 'vote-1',
      reviewerId: 'judge-a',
      optionA: _ref(
        profileName: 'candidate',
        traceDigest: _digest('candidate-trace'),
        cascadeWake: const EvalTraceCascadeWake(
          cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
          wakeIndex: 1,
          wakeCount: 3,
        ),
      ),
      optionB: _ref(
        profileName: 'baseline',
        traceDigest: _digest('baseline-trace'),
        cascadeWake: const EvalTraceCascadeWake(
          cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
          wakeIndex: 1,
          wakeCount: 3,
        ),
      ),
    );

    final roundTripped = EvalPairwisePreferenceVote.fromJson(vote.toJson());

    expect(roundTripped.optionA.runId, 'run-1');
    expect(roundTripped.optionA.agentKind, AgentKind.taskAgent);
    expect(roundTripped.optionA.cascadeWake?.wakeIndex, 1);
    expect(roundTripped.optionB.cascadeWake?.wakeCount, 3);
    expect(roundTripped.peerVotesVisible, isFalse);
    expect(roundTripped.traceOrderRandomized, isTrue);
    expect(roundTripped.comparisonKey, vote.comparisonKey);
    expect(
      roundTripped.validate(const EvalPairwisePreferencePolicy()),
      isEmpty,
    );
  });

  test(
    'summarizes a quorum winner without treating it as scalar promotion',
    () {
      final optionA = _ref(
        profileName: 'candidate',
        traceDigest: _digest('optionA'),
      );
      final optionB = _ref(
        profileName: 'baseline',
        traceDigest: _digest('optionB'),
      );
      final votes = [
        _vote(
          voteId: 'vote-1',
          reviewerId: 'judge-a',
          optionA: optionA,
          optionB: optionB,
        ),
        _vote(
          voteId: 'vote-2',
          reviewerId: 'judge-b',
          optionA: optionA,
          optionB: optionB,
        ),
        _vote(
          voteId: 'vote-3',
          reviewerId: 'judge-c',
          optionA: optionA,
          optionB: optionB,
          choice: EvalPairwisePreferenceChoice.optionB,
        ),
      ];

      final summary = EvalPairwisePreferenceReporter.summarize(votes).single;
      final rendered = EvalPairwisePreferenceReporter.render([summary]);

      expect(summary.optionA.profileName, 'baseline');
      expect(summary.optionB.profileName, 'candidate');
      expect(summary.status, EvalPairwisePreferenceStatus.optionBWins);
      expect(summary.preferredTrace?.profileName, 'candidate');
      expect(summary.hasWinner, isTrue);
      expect(summary.voteCount, 3);
      expect(summary.validVoteCount, 3);
      expect(summary.optionAVoteCount, 1);
      expect(summary.optionBVoteCount, 2);
      expect(summary.quorumThreshold, 2);
      expect(rendered, contains('Pairwise preference summary'));
      expect(rendered, contains('optionBWins'));
    },
  );

  test('canonicalizes randomized optionA-optionB order before quorum', () {
    final candidate = _ref(
      profileName: 'candidate',
      traceDigest: _digest('candidate'),
    );
    final baseline = _ref(
      profileName: 'baseline',
      traceDigest: _digest('baseline'),
    );

    final summary = EvalPairwisePreferenceReporter.summarize([
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: candidate,
        optionB: baseline,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: baseline,
        optionB: candidate,
        choice: EvalPairwisePreferenceChoice.optionB,
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-c',
        optionA: baseline,
        optionB: candidate,
      ),
    ]).single;

    expect(summary.optionA.profileName, 'baseline');
    expect(summary.optionB.profileName, 'candidate');
    expect(summary.status, EvalPairwisePreferenceStatus.optionBWins);
    expect(summary.preferredTrace?.profileName, 'candidate');
    expect(summary.optionAVoteCount, 1);
    expect(summary.optionBVoteCount, 2);
  });

  test('reports incomplete and no-consensus preference sets', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
    );

    final incomplete = EvalPairwisePreferenceReporter.summarize([
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: optionA,
        optionB: optionB,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
      ),
    ]).single;
    final noConsensus = EvalPairwisePreferenceReporter.summarize([
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: optionA,
        optionB: optionB,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
        choice: EvalPairwisePreferenceChoice.optionB,
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-c',
        optionA: optionA,
        optionB: optionB,
        choice: EvalPairwisePreferenceChoice.tie,
      ),
    ]).single;

    expect(incomplete.status, EvalPairwisePreferenceStatus.incomplete);
    expect(incomplete.findings.single, contains('valid votes 2 < minVotes 3'));
    expect(noConsensus.status, EvalPairwisePreferenceStatus.noConsensus);
    expect(noConsensus.findings.single, contains('no choice reached quorum'));
  });

  test('invalidates unblinded and duplicate-reviewer votes', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
    );
    final summary = EvalPairwisePreferenceReporter.summarize([
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: optionA,
        optionB: optionB,
        modelIdentityVisible: true,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
      ),
    ]).single;

    expect(summary.status, EvalPairwisePreferenceStatus.invalid);
    expect(summary.invalidVoteCount, 3);
    expect(summary.findings.join('\n'), contains('reviewer saw exact model'));
    expect(summary.findings.join('\n'), contains('duplicate reviewer'));
  });

  test('invalidates incompatible pairwise trace refs', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
      agentKind: AgentKind.planningAgent,
    );
    final summary = EvalPairwisePreferenceReporter.summarize([
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: optionA,
        optionB: optionB,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-c',
        optionA: optionA,
        optionB: optionB,
      ),
    ]).single;

    expect(summary.status, EvalPairwisePreferenceStatus.invalid);
    expect(summary.invalidVoteCount, 3);
    expect(summary.findings.join('\n'), contains('must share agentKind'));
  });

  test('invalidates peer-visible votes and non-randomized order by policy', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
    );
    final summary = EvalPairwisePreferenceReporter.summarize(
      [
        _vote(
          voteId: 'vote-1',
          reviewerId: 'judge-a',
          optionA: optionA,
          optionB: optionB,
          peerVotesVisible: true,
        ),
        _vote(
          voteId: 'vote-2',
          reviewerId: 'judge-b',
          optionA: optionA,
          optionB: optionB,
          traceOrderRandomized: false,
        ),
        _vote(
          voteId: 'vote-3',
          reviewerId: 'judge-c',
          optionA: optionA,
          optionB: optionB,
        ),
      ],
      policy: const EvalPairwisePreferencePolicy(
        requireTraceOrderRandomized: true,
      ),
    ).single;

    expect(summary.status, EvalPairwisePreferenceStatus.invalid);
    expect(summary.invalidVoteCount, 2);
    expect(summary.findings.join('\n'), contains('reviewer saw peer votes'));
    expect(
      summary.findings.join('\n'),
      contains('trace order was not randomized'),
    );
  });
}

EvalPairwiseTraceRef _ref({
  required String profileName,
  required String traceDigest,
  AgentKind agentKind = AgentKind.taskAgent,
  EvalTraceCascadeWake? cascadeWake,
}) => EvalPairwiseTraceRef(
  runId: 'run-1',
  scenarioId: 'task_pairwise',
  profileName: profileName,
  agentKind: agentKind,
  modelClass: EvalModelClass.frontierReasoning,
  capabilityId: 'task.grooming.basic',
  trialIndex: 0,
  cascadeWake: cascadeWake,
  traceDigest: traceDigest,
  scenarioDigest: _digest('scenario'),
  profileDigest: _digest('profile-$profileName'),
);

EvalPairwisePreferenceVote _vote({
  required String voteId,
  required String reviewerId,
  required EvalPairwiseTraceRef optionA,
  required EvalPairwiseTraceRef optionB,
  EvalPairwisePreferenceChoice choice = EvalPairwisePreferenceChoice.optionA,
  bool modelIdentityVisible = false,
  bool peerVotesVisible = false,
  bool traceOrderRandomized = true,
}) => EvalPairwisePreferenceVote(
  voteId: voteId,
  optionA: optionA,
  optionB: optionB,
  reviewerId: reviewerId,
  reviewerKind: EvalPairwiseReviewerKind.llmJudge,
  reviewerModel: 'claude-code-test',
  promptDigest: _digest('pairwise-prompt'),
  calibrationSetVersion: 'pairwise-gold-v1',
  profileVisible: false,
  modelIdentityVisible: modelIdentityVisible,
  peerVotesVisible: peerVotesVisible,
  traceOrderRandomized: traceOrderRandomized,
  choice: choice,
  rationale: 'The selected trace is more faithful and concise.',
);

String _digest(String value) => EvalProvenance.digestText(value);
