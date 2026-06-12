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

  test('rejects unsupported preference vote schema versions', () {
    final vote = _vote(
      voteId: 'vote-schema',
      reviewerId: 'judge-a',
      optionA: _ref(profileName: 'candidate', traceDigest: _digest('left')),
      optionB: _ref(profileName: 'baseline', traceDigest: _digest('right')),
    ).toJson()..['schemaVersion'] = 1.5;

    expect(
      () => EvalPairwisePreferenceVote.fromJson(vote),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported EvalPairwisePreferenceVote schemaVersion 1.5'),
        ),
      ),
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
      expect(summary.axis, EvalPairwiseComparisonAxis.profile);
      expect(summary.status, EvalPairwisePreferenceStatus.optionBWins);
      expect(summary.preferredTrace?.profileName, 'candidate');
      expect(summary.hasWinner, isTrue);
      expect(summary.voteCount, 3);
      expect(summary.validVoteCount, 3);
      expect(summary.optionAVoteCount, 1);
      expect(summary.optionBVoteCount, 2);
      expect(summary.quorumThreshold, 2);
      expect(
        rendered,
        contains('Subjective A/B preference votes (diagnostic only)'),
      );
      expect(rendered, contains('optionBWins'));
      expect(rendered, contains('profile'));
    },
  );

  test('summarizes prompt-variant comparisons for the same profile', () {
    final defaultVariant = _ref(
      profileName: 'candidate',
      traceDigest: _digest('default-variant'),
    );
    final tunedVariant = _ref(
      profileName: 'candidate',
      agentDirectiveVariantName: 'metadata-first-v2',
      traceDigest: _digest('tuned-variant'),
    );
    final votes = [
      _vote(
        voteId: 'vote-1',
        reviewerId: 'judge-a',
        optionA: tunedVariant,
        optionB: defaultVariant,
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: tunedVariant,
        optionB: defaultVariant,
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-c',
        optionA: defaultVariant,
        optionB: tunedVariant,
        choice: EvalPairwisePreferenceChoice.optionB,
      ),
    ];

    final summary = EvalPairwisePreferenceReporter.summarize(votes).single;
    final rendered = EvalPairwisePreferenceReporter.render([summary]);

    expect(summary.axis, EvalPairwiseComparisonAxis.promptVariant);
    expect(
      summary.preferredTrace?.agentDirectiveVariantName,
      'metadata-first-v2',
    );
    expect(summary.status, EvalPairwisePreferenceStatus.optionAWins);
    expect(summary.validVoteCount, 3);
    expect(summary.optionAVoteCount, 3);
    expect(rendered, contains('promptVariant'));
    expect(rendered, contains('metadata-first'));
  });

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
    expect(summary.axis, EvalPairwiseComparisonAxis.profile);
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

  test('invalidates mixed review protocols before quorum', () {
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
      ),
      _vote(
        voteId: 'vote-2',
        reviewerId: 'judge-b',
        optionA: optionA,
        optionB: optionB,
        promptDigest: _digest('alternate-prompt'),
      ),
      _vote(
        voteId: 'vote-3',
        reviewerId: 'judge-c',
        optionA: optionA,
        optionB: optionB,
        calibrationSetVersion: 'pairwise-gold-v2',
      ),
    ]).single;

    expect(summary.status, EvalPairwisePreferenceStatus.invalid);
    expect(summary.invalidVoteCount, 3);
    expect(summary.optionAVoteCount, 0);
    expect(summary.findings.join('\n'), contains('mixed review protocol'));
    expect(summary.findings.join('\n'), contains('pairwise-gold-v2'));
  });

  test('can require blinded import provenance for model-class tuning', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
    );
    final vote = _vote(
      voteId: 'vote-1',
      reviewerId: 'judge-a',
      optionA: optionA,
      optionB: optionB,
    );
    final importedVote = vote.withBlindedImport(
      BlindedPairwisePreferenceImportRecord(
        blindedPairId: 'pair-0001',
        reviewPayloadDigest: _digest('review-payload'),
        judgeManifestDigest: _digest('judge-manifest'),
        privateKeyDigest: _digest('private-key'),
        sourceManifestDigest: _digest('manifest'),
        optionARawTraceDigest: optionA.traceDigest,
        optionBRawTraceDigest: optionB.traceDigest,
      ),
    );

    final selfAttested = EvalPairwisePreferenceReporter.summarize(
      [vote],
      policy: const EvalPairwisePreferencePolicy(
        minVotes: 1,
        requireBlindedImport: true,
      ),
    ).single;
    final imported = EvalPairwisePreferenceReporter.summarize(
      [importedVote],
      policy: const EvalPairwisePreferencePolicy(
        minVotes: 1,
        requireBlindedImport: true,
      ),
    ).single;

    expect(selfAttested.status, EvalPairwisePreferenceStatus.invalid);
    expect(
      selfAttested.findings.join('\n'),
      contains('missing blinded pairwise import provenance'),
    );
    expect(imported.hasWinner, isTrue);
    expect(imported.preferredTrace?.profileName, 'candidate');
    expect(imported.invalidVoteCount, 0);
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

  test('invalidates confounded and stale tuning-axis comparisons', () {
    final defaultCandidate = _ref(
      profileName: 'candidate',
      traceDigest: _digest('candidate-default'),
    );
    final tunedBaseline = _ref(
      profileName: 'baseline',
      agentDirectiveVariantName: 'metadata-first-v2',
      traceDigest: _digest('baseline-tuned'),
    );
    final staleVariantBaseline = _ref(
      profileName: 'baseline',
      traceDigest: _digest('baseline-stale-variant'),
      agentDirectiveVariantDigest: _digest('stale-variant'),
    );
    final staleProfileCandidate = _ref(
      profileName: 'candidate',
      agentDirectiveVariantName: 'metadata-first-v2',
      traceDigest: _digest('candidate-stale-profile'),
      profileDigest: _digest('stale-profile'),
    );
    final summaries = EvalPairwisePreferenceReporter.summarize(
      [
        _vote(
          voteId: 'vote-confounded',
          reviewerId: 'judge-a',
          optionA: defaultCandidate,
          optionB: tunedBaseline,
        ),
        _vote(
          voteId: 'vote-stale-variant',
          reviewerId: 'judge-b',
          optionA: defaultCandidate,
          optionB: staleVariantBaseline,
        ),
        _vote(
          voteId: 'vote-stale-profile',
          reviewerId: 'judge-c',
          optionA: defaultCandidate,
          optionB: staleProfileCandidate,
        ),
      ],
      policy: const EvalPairwisePreferencePolicy(minVotes: 1),
    );

    expect(summaries, hasLength(3));
    expect(
      summaries.map((summary) => summary.status),
      everyElement(EvalPairwisePreferenceStatus.invalid),
    );
    expect(
      summaries.expand((summary) => summary.findings).join('\n'),
      allOf(
        contains('must differ by exactly one tuning axis'),
        contains('must share agentDirectiveVariantDigest'),
        contains('must share profileDigest'),
      ),
    );
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

  test('rejects invalid preference policy gates', () {
    final optionA = _ref(
      profileName: 'candidate',
      traceDigest: _digest('optionA'),
    );
    final optionB = _ref(
      profileName: 'baseline',
      traceDigest: _digest('optionB'),
    );

    for (final policy in const [
      EvalPairwisePreferencePolicy(minVotes: 0),
      EvalPairwisePreferencePolicy(quorumFraction: 0),
      EvalPairwisePreferencePolicy(quorumFraction: 1.5),
      EvalPairwisePreferencePolicy(quorumFraction: double.nan),
    ]) {
      expect(
        () => EvalPairwisePreferenceReporter.summarize(
          [
            _vote(
              voteId: 'vote-1',
              reviewerId: 'judge-a',
              optionA: optionA,
              optionB: optionB,
            ),
          ],
          policy: policy,
        ),
        throwsA(isA<ArgumentError>()),
      );
    }
  });
}

EvalPairwiseTraceRef _ref({
  required String profileName,
  required String traceDigest,
  String agentDirectiveVariantName = 'default',
  String? agentDirectiveVariantDigest,
  String? profileDigest,
  AgentKind agentKind = AgentKind.taskAgent,
  EvalTraceCascadeWake? cascadeWake,
}) => EvalPairwiseTraceRef(
  runId: 'run-1',
  scenarioId: 'task_pairwise',
  profileName: profileName,
  agentDirectiveVariantName: agentDirectiveVariantName,
  agentKind: agentKind,
  modelClass: EvalModelClass.frontierReasoning,
  capabilityId: 'task.grooming.basic',
  trialIndex: 0,
  cascadeWake: cascadeWake,
  traceDigest: traceDigest,
  scenarioDigest: _digest('scenario'),
  profileDigest: profileDigest ?? _digest('profile-$profileName'),
  agentDirectiveVariantDigest:
      agentDirectiveVariantDigest ??
      (agentDirectiveVariantName == 'default'
          ? EvalProvenance.agentDirectiveVariantDigest(
              const EvalAgentDirectiveVariant(),
            )
          : _digest('variant-$agentDirectiveVariantName')),
);

EvalPairwisePreferenceVote _vote({
  required String voteId,
  required String reviewerId,
  required EvalPairwiseTraceRef optionA,
  required EvalPairwiseTraceRef optionB,
  EvalPairwisePreferenceChoice choice = EvalPairwisePreferenceChoice.optionA,
  String? promptDigest,
  String calibrationSetVersion = 'pairwise-gold-v1',
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
  promptDigest: promptDigest ?? _digest('pairwise-prompt'),
  calibrationSetVersion: calibrationSetVersion,
  profileVisible: false,
  modelIdentityVisible: modelIdentityVisible,
  peerVotesVisible: peerVotesVisible,
  traceOrderRandomized: traceOrderRandomized,
  choice: choice,
  rationale: 'The selected trace is more faithful and concise.',
);

String _digest(String value) => EvalProvenance.digestText(value);
