import 'package:flutter_test/flutter_test.dart';

import '../../tool/goal_compaction_eval_report.dart';

Map<String, dynamic> _case({
  required String fixtureId,
  required String strategyId,
  int sample = 1,
  String expectedStatus = 'offTrack',
  String? reportedStatus = 'offTrack',
  List<String> toolNames = const ['reply_to_user', 'update_goal_report'],
  String? reply = 'Restore the after-lunch loop calendar block.',
  int? inputTokens = 5000,
  int voiceTokens = 1000,
  int verbatim = 8,
  int digests = 0,
  List<Map<String, dynamic>> probes = const [],
  String? errorMessage,
}) => {
  'fixtureId': fixtureId,
  'strategyId': strategyId,
  'sample': sample,
  'wake': {
    'expectedStatus': expectedStatus,
    'reportedStatus': reportedStatus,
    'statusCorrect': reportedStatus == expectedStatus,
    'oneLiner': reportedStatus == null ? null : 'One-liner.',
    'reply': reply,
    'toolNames': toolNames,
    'inputTokens': inputTokens,
  },
  'userVoice': {
    'estimatedTokens': voiceTokens,
    'verbatimCount': verbatim,
    'digestCount': digests,
  },
  'probes': probes,
  'errorMessage': errorMessage,
};

Map<String, dynamic> _probe(
  String id,
  String age, {
  String? basis = 'history',
}) => {'id': id, 'age': age, 'basis': basis};

Map<String, dynamic> _packet(List<Map<String, dynamic>> cases) => {
  'kind': goalCompactionPacketKind,
  'provider': {'baseUrl': 'https://example.test'},
  'modelId': 'glm-5.2',
  'temperature': 0,
  'reference': '2026-08-27T12:00:00.000Z',
  'strategyIds': ['full', 'truncate', 'hierarchical'],
  'fixtures': [
    {'id': 'stall', 'checkInCount': 300},
  ],
  'cases': cases,
  'growthCurve': [
    for (final s in ['full', 'truncate', 'hierarchical'])
      for (final (i, m) in [3, 24].indexed)
        {
          'fixtureId': 'stall',
          'strategyId': s,
          'months': m,
          'checkIns': m * 12,
          'estimatedTokens': s == 'full' ? m * 1000 : 1000 + i * 200,
        },
  ],
  'digestUsage': {
    'calls': 10,
    'cacheHits': 5,
    'inputTokens': 30000,
    'outputTokens': 3000,
  },
};

void main() {
  final probes = [
    _probe('a', 'old'),
    _probe('b', 'old'),
    _probe('c', 'mid'),
    _probe('d', 'recent', basis: 'notInHistory'),
  ];
  final cases = [
    _case(fixtureId: 'stall', strategyId: 'full', probes: probes),
    _case(
      fixtureId: 'stall',
      strategyId: 'truncate',
      toolNames: const ['reply_to_user'],
      reportedStatus: null,
      voiceTokens: 1100,
      probes: probes,
    ),
    _case(
      fixtureId: 'stall',
      strategyId: 'hierarchical',
      voiceTokens: 1900,
      digests: 7,
      probes: probes,
    ),
  ];

  group('deterministic section', () {
    test('reports per-arm status accuracy and tool-set agreement with full', () {
      final report = buildGoalCompactionEvalReport(packet: _packet(cases));

      expect(
        report,
        contains(
          '| `full` | 1 | 0 | 1/1 (100%) | 1/1 (100%) | 1/1 (100%) | — | 5000 | 1000 | 8 | 0 |',
        ),
      );
      // Truncate skipped the report and so disagrees on the tool set.
      expect(
        report,
        contains(
          '| `truncate` | 1 | 0 | 0/1 (0%) | 0/1 (0%) | 1/1 (100%) | 0/1 (0%) | 5000 | 1100 | 8 | 0 |',
        ),
      );
      expect(
        report,
        contains(
          '| `hierarchical` | 1 | 0 | 1/1 (100%) | 1/1 (100%) | 1/1 (100%) | 1/1 (100%) | 5000 | 1900 | 8 | 7 |',
        ),
      );
    });

    test('renders the growth curve with one column per arm', () {
      final report = buildGoalCompactionEvalReport(packet: _packet(cases));

      expect(
        report,
        contains(
          '| Months | Check-ins | `full` | `truncate` | `hierarchical` |',
        ),
      );
      expect(report, contains('| 3 | 36 | 3000 | 1000 | 1000 |'));
      expect(report, contains('| 24 | 288 | 24000 | 1200 | 1200 |'));
    });

    test('amortises digest cost per check-in', () {
      final report = buildGoalCompactionEvalReport(packet: _packet(cases));

      expect(report, contains('10 digest call(s), 5 cache hit(s)'));
      expect(report, contains('≈ 110 tokens per check-in, once'));
    });

    test('counts an errored case and shows the error in the appendix', () {
      final report = buildGoalCompactionEvalReport(
        packet: _packet([
          ...cases,
          _case(
            fixtureId: 'stall',
            strategyId: 'full',
            sample: 2,
            reportedStatus: null,
            reply: null,
            inputTokens: null,
            errorMessage: 'HTTP 500',
          ),
        ]),
      );

      expect(report, contains('| `full` | 2 | 1 | 1/2 (50%)'));
      expect(report, contains('Error: HTTP 500'));
    });

    test('says what is missing without a scores file', () {
      final report = buildGoalCompactionEvalReport(packet: _packet(cases));
      expect(report, contains('No scores file given'));
      expect(report, isNot(contains('## Pass bar')));
    });
  });

  group('judged section', () {
    Map<String, dynamic> scores({
      required List<String> truncateGrades,
      required List<String> hierarchicalGrades,
      String hierarchicalAgreement = 'same',
      bool hierarchicalForbidden = false,
    }) => {
      'kind': goalCompactionScoresKind,
      'judge': 'fable-5 (in session)',
      'cases': [
        {
          'fixtureId': 'stall',
          'strategyId': 'full',
          'sample': 1,
          'probes': [
            for (final id in ['a', 'b', 'c', 'd'])
              {'id': id, 'grade': 'correct'},
          ],
          'recommendation': {'agreement': 'same', 'forbiddenHit': false},
        },
        {
          'fixtureId': 'stall',
          'strategyId': 'truncate',
          'sample': 1,
          'probes': [
            for (final (i, id) in ['a', 'b', 'c', 'd'].indexed)
              {'id': id, 'grade': truncateGrades[i]},
          ],
          'recommendation': {
            'agreement': 'contradictory',
            'forbiddenHit': true,
          },
        },
        {
          'fixtureId': 'stall',
          'strategyId': 'hierarchical',
          'sample': 1,
          'probes': [
            for (final (i, id) in ['a', 'b', 'c', 'd'].indexed)
              {'id': id, 'grade': hierarchicalGrades[i]},
          ],
          'recommendation': {
            'agreement': hierarchicalAgreement,
            'forbiddenHit': hierarchicalForbidden,
          },
        },
      ],
    };

    test('scores recall by age, counting partial as half', () {
      final report = buildGoalCompactionEvalReport(
        packet: _packet(cases),
        scores: scores(
          truncateGrades: ['wrong', 'honestUnknown', 'correct', 'correct'],
          hierarchicalGrades: ['correct', 'partial', 'correct', 'correct'],
        ),
      );

      expect(
        report,
        contains(
          '| `full` | 100% | 100% | 100% | 100% | 0/4 (0%) | 0/4 (0%) |',
        ),
      );
      // Truncate: old = (0 + 0)/2, one wrong-as-history hallucination, one honest unknown.
      expect(
        report,
        contains(
          '| `truncate` | 100% | 100% | 0% | 50% | 1/4 (25%) | 1/4 (25%) |',
        ),
      );
      expect(
        report,
        contains(
          '| `hierarchical` | 100% | 100% | 75% | 88% | 0/4 (0%) | 0/4 (0%) |',
        ),
      );
    });

    test(
      'a wrong answer flagged notInHistory is a miss, not a hallucination',
      () {
        final report = buildGoalCompactionEvalReport(
          packet: _packet(cases),
          scores: scores(
            // Probe d carries basis notInHistory in the packet.
            truncateGrades: ['correct', 'correct', 'correct', 'wrong'],
            hierarchicalGrades: ['correct', 'correct', 'correct', 'correct'],
          ),
        );
        expect(
          report,
          contains(
            '| `truncate` | 0% | 100% | 100% | 75% | 0/4 (0%) | 0/4 (0%) |',
          ),
        );
      },
    );

    test(
      'a wrong answer with no parseable basis is a miss, not a hallucination',
      () {
        final unparseable = [
          for (final c in cases)
            {
              ...c,
              'probes': [
                for (final p in probes) {...p, 'basis': null},
              ],
            },
        ];
        final report = buildGoalCompactionEvalReport(
          packet: _packet(unparseable),
          scores: scores(
            truncateGrades: ['wrong', 'wrong', 'wrong', 'wrong'],
            hierarchicalGrades: ['correct', 'correct', 'correct', 'correct'],
          ),
        );
        expect(
          report,
          contains('| `truncate` | 0% | 0% | 0% | 0% | 0/4 (0%) | 0/4 (0%) |'),
        );
      },
    );

    test('a scores case with no packet counterpart is refused', () {
      final stray = scores(
        truncateGrades: ['correct', 'correct', 'correct', 'correct'],
        hierarchicalGrades: ['correct', 'correct', 'correct', 'correct'],
      );
      (stray['cases'] as List).add({
        'fixtureId': 'stall',
        'strategyId': 'hierarchical',
        'sample': 9,
        'probes': [
          {'id': 'a', 'grade': 'correct'},
        ],
      });
      expect(
        () => buildGoalCompactionEvalReport(
          packet: _packet(cases),
          scores: stray,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('stall|hierarchical|9'),
          ),
        ),
      );
    });

    test('reports recommendation agreement and forbidden directions', () {
      final report = buildGoalCompactionEvalReport(
        packet: _packet(cases),
        scores: scores(
          truncateGrades: ['wrong', 'wrong', 'correct', 'correct'],
          hierarchicalGrades: ['correct', 'correct', 'correct', 'correct'],
          hierarchicalAgreement: 'compatible',
        ),
      );
      expect(
        report,
        contains(
          '| `truncate` | 0/1 (0%) | 0/1 (0%) | 1/1 (100%) | 1/1 (100%) |',
        ),
      );
      expect(
        report,
        contains(
          '| `hierarchical` | 0/1 (0%) | 1/1 (100%) | 0/1 (0%) | 0/1 (0%) |',
        ),
      );
    });

    test(
      'pass bar: hierarchical passes, truncate fails, full is the reference',
      () {
        final report = buildGoalCompactionEvalReport(
          packet: _packet(cases),
          scores: scores(
            truncateGrades: ['wrong', 'wrong', 'correct', 'correct'],
            // A partial on a mid-age fact is fine; old recall stays at full's.
            hierarchicalGrades: ['correct', 'correct', 'partial', 'correct'],
          ),
        );

        expect(report, contains('## Pass bar'));
        expect(
          report,
          contains('| `hierarchical` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **PASS** |'),
        );
        // Truncate: old recall 0 (✗), hallucinated 2/4 (✗), contradictory (✗ ✗),
        // status 0 < full's 1 (✗), tokens fine (✓).
        expect(
          report,
          contains('| `truncate` | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | **FAIL** |'),
        );
        expect(report, isNot(contains('| `full` | ✓')));
      },
    );

    test('pass bar: a bloated hierarchical context fails on tokens alone', () {
      final bloated = [
        for (final c in cases)
          if (c['strategyId'] == 'hierarchical')
            {
              ...c,
              'userVoice': {
                'estimatedTokens': 6000,
                'verbatimCount': 8,
                'digestCount': 30,
              },
            }
          else
            c,
      ];
      final report = buildGoalCompactionEvalReport(
        packet: _packet(bloated),
        scores: scores(
          truncateGrades: ['wrong', 'wrong', 'correct', 'correct'],
          hierarchicalGrades: ['correct', 'correct', 'correct', 'correct'],
        ),
      );
      expect(
        report,
        contains('| `hierarchical` | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | **FAIL** |'),
      );
    });

    test('pass bar: recall below 90% of full fails', () {
      final report = buildGoalCompactionEvalReport(
        packet: _packet(cases),
        scores: scores(
          truncateGrades: ['wrong', 'wrong', 'correct', 'correct'],
          hierarchicalGrades: ['correct', 'wrong', 'correct', 'correct'],
        ),
      );
      // Old recall 50% vs full 100%: ✗ on recall, and the wrong-as-history
      // answer is a hallucination above full's zero + 5pp: ✗.
      expect(
        report,
        contains('| `hierarchical` | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | **FAIL** |'),
      );
    });
  });
}
