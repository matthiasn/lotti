import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/run_key_factory.dart';

final _fixedTime = DateTime(2024, 3, 15, 10, 30);

/// Helper to compute SHA-256 the same way RunKeyFactory does internally.
String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

enum _GeneratedRunKeyTokenSlot { first, second, third, fourth }

enum _GeneratedRunKeyRefSlot { task, project, journal, label }

String _generatedRunKeyToken(_GeneratedRunKeyTokenSlot slot) =>
    'generated-token-${slot.name}';

String _generatedRunKeyRef(_GeneratedRunKeyRefSlot slot) =>
    'generated-ref-${slot.name}';

class _GeneratedRunKeyCanonicalizationScenario {
  const _GeneratedRunKeyCanonicalizationScenario({
    required this.tokens,
    required this.refs,
    required this.seed,
  });

  final List<_GeneratedRunKeyTokenSlot> tokens;
  final List<_GeneratedRunKeyRefSlot> refs;
  final int seed;

  Set<String> get tokenSet => tokens.map(_generatedRunKeyToken).toSet();

  List<String> get targetRefs => refs.map(_generatedRunKeyRef).toList();

  Map<String, dynamic> get argsInOriginalOrder => {
    'title': 'Generated title $seed',
    'count': seed,
    'enabled': seed.isEven,
  };

  Map<String, dynamic> get argsInDifferentOrder => {
    'enabled': seed.isEven,
    'count': seed,
    'title': 'Generated title $seed',
  };

  @override
  String toString() {
    return '_GeneratedRunKeyCanonicalizationScenario('
        'tokens: $tokens, refs: $refs, seed: $seed)';
  }
}

extension _AnyGeneratedRunKeyScenario on glados.Any {
  glados.Generator<_GeneratedRunKeyTokenSlot> get runKeyTokenSlot =>
      glados.AnyUtils(this).choose(_GeneratedRunKeyTokenSlot.values);

  glados.Generator<_GeneratedRunKeyRefSlot> get runKeyRefSlot =>
      glados.AnyUtils(this).choose(_GeneratedRunKeyRefSlot.values);

  glados.Generator<_GeneratedRunKeyCanonicalizationScenario>
  get runKeyCanonicalizationScenario => glados.CombinableAny(this).combine3(
    glados.ListAnys(this).listWithLengthInRange(0, 8, runKeyTokenSlot),
    glados.ListAnys(this).listWithLengthInRange(0, 8, runKeyRefSlot),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      List<_GeneratedRunKeyTokenSlot> tokens,
      List<_GeneratedRunKeyRefSlot> refs,
      int seed,
    ) => _GeneratedRunKeyCanonicalizationScenario(
      tokens: tokens,
      refs: refs,
      seed: seed,
    ),
  );
}

void main() {
  group('RunKeyFactory', () {
    group('forSubscription', () {
      test('produces deterministic key for same inputs', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a', 'tok-b'},
          wakeCounter: 3,
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-b', 'tok-a'},
          wakeCounter: 3,
          timestamp: _fixedTime,
        );

        expect(
          key1,
          equals(key2),
          reason: 'Token order must not affect the key',
        );
      });

      test('differs when agentId changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-2',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when subscriptionId changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-2',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when batchTokens change', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-b'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when wakeCounter changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 1,
          timestamp: _fixedTime,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('produces valid SHA-256 hex string', () {
        final key = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: _fixedTime,
        );

        expect(key, hasLength(64));
        expect(key, matches(RegExp(r'^[a-f0-9]{64}$')));
      });

      test('matches manual SHA-256 computation', () {
        const agentId = 'agent-1';
        const subscriptionId = 'sub-1';
        final batchTokens = {'tok-b', 'tok-a'};
        const wakeCounter = 5;

        final sortedTokens = batchTokens.toList()..sort();
        final batchTokensHash = _sha256(sortedTokens.join('|'));
        final expected = _sha256(
          '$agentId|$subscriptionId|$batchTokensHash|$wakeCounter'
          '|${_fixedTime.toIso8601String()}',
        );

        final actual = RunKeyFactory.forSubscription(
          agentId: agentId,
          subscriptionId: subscriptionId,
          batchTokens: batchTokens,
          wakeCounter: wakeCounter,
          timestamp: _fixedTime,
        );

        expect(actual, equals(expected));
      });

      test('differs when timestamp changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: DateTime(2024, 3, 15, 10, 30),
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
          timestamp: DateTime(2024, 3, 15, 10, 31),
        );

        expect(key1, isNot(equals(key2)));
      });
    });

    group('forManual', () {
      test('produces deterministic key for same inputs', () {
        final ts = DateTime(2024, 3, 15, 10, 30);
        final key1 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'creation',
          timestamp: ts,
        );
        final key2 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'creation',
          timestamp: ts,
        );

        expect(key1, equals(key2));
      });

      test('differs when reason changes', () {
        final ts = DateTime(2024, 3, 15, 10, 30);
        final key1 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'creation',
          timestamp: ts,
        );
        final key2 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'reanalysis',
          timestamp: ts,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when timestamp changes', () {
        final key1 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'creation',
          timestamp: DateTime(2024, 3, 15, 10, 30),
        );
        final key2 = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'creation',
          timestamp: DateTime(2024, 3, 15, 10, 31),
        );

        expect(key1, isNot(equals(key2)));
      });

      test('matches manual SHA-256 computation', () {
        const agentId = 'agent-1';
        const reason = 'creation';
        final ts = DateTime(2024, 3, 15, 10, 30);
        final expected = _sha256('$agentId|$reason|${ts.toIso8601String()}');

        final actual = RunKeyFactory.forManual(
          agentId: agentId,
          reason: reason,
          timestamp: ts,
        );

        expect(actual, equals(expected));
      });

      test('inserts the workspace segment when workspaceKey is non-null', () {
        const agentId = 'agent-1';
        const reason = 'scheduled';
        const workspaceKey = 'day:dayplan-2024-03-15';
        final ts = DateTime(2024, 3, 15, 10, 30);
        final expected = _sha256(
          '$agentId|$reason|$workspaceKey|${ts.toIso8601String()}',
        );

        final actual = RunKeyFactory.forManual(
          agentId: agentId,
          reason: reason,
          timestamp: ts,
          workspaceKey: workspaceKey,
        );

        expect(actual, equals(expected));
      });

      test('omitted workspaceKey stays byte-identical to a null one', () {
        final ts = DateTime(2024, 3, 15, 10, 30);
        final withoutKey = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'scheduled',
          timestamp: ts,
        );
        final withNullKey = RunKeyFactory.forManual(
          agentId: 'agent-1',
          reason: 'scheduled',
          // Explicit null is the point of this test (omitted == null).
          // ignore: avoid_redundant_argument_values
          workspaceKey: null,
          timestamp: ts,
        );

        expect(withoutKey, equals(withNullKey));
      });

      test('same-tick wakes for different workspaces do not collide', () {
        final ts = DateTime(2024, 3, 15, 10, 30);
        final dayA = RunKeyFactory.forManual(
          agentId: 'daily_os_planner',
          reason: 'scheduled',
          timestamp: ts,
          workspaceKey: 'day:dayplan-2024-03-15',
        );
        final dayB = RunKeyFactory.forManual(
          agentId: 'daily_os_planner',
          reason: 'scheduled',
          timestamp: ts,
          workspaceKey: 'day:dayplan-2024-03-16',
        );

        expect(dayA, isNot(equals(dayB)));
      });
    });

    group('operationId', () {
      test('produces deterministic key for same inputs', () {
        final id1 = RunKeyFactory.operationId(
          runKey: 'run-key-1',
          actionStableId: 'action-1',
        );
        final id2 = RunKeyFactory.operationId(
          runKey: 'run-key-1',
          actionStableId: 'action-1',
        );

        expect(id1, equals(id2));
      });

      test('differs when runKey changes', () {
        final id1 = RunKeyFactory.operationId(
          runKey: 'run-key-1',
          actionStableId: 'action-1',
        );
        final id2 = RunKeyFactory.operationId(
          runKey: 'run-key-2',
          actionStableId: 'action-1',
        );

        expect(id1, isNot(equals(id2)));
      });

      test('differs when actionStableId changes', () {
        final id1 = RunKeyFactory.operationId(
          runKey: 'run-key-1',
          actionStableId: 'action-1',
        );
        final id2 = RunKeyFactory.operationId(
          runKey: 'run-key-1',
          actionStableId: 'action-2',
        );

        expect(id1, isNot(equals(id2)));
      });
    });

    group('actionStableId', () {
      test('produces deterministic key for same inputs', () {
        final id1 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff', 'priority': 1},
          targetRefs: ['ref-a', 'ref-b'],
        );
        final id2 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff', 'priority': 1},
          targetRefs: ['ref-b', 'ref-a'],
        );

        expect(
          id1,
          equals(id2),
          reason: 'targetRefs order must not affect the key',
        );
      });

      test('differs when toolName changes', () {
        final id1 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff'},
          targetRefs: ['ref-a'],
        );
        final id2 = RunKeyFactory.actionStableId(
          toolName: 'deleteTask',
          args: {'title': 'Do stuff'},
          targetRefs: ['ref-a'],
        );

        expect(id1, isNot(equals(id2)));
      });

      test('differs when args change', () {
        final id1 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff'},
          targetRefs: ['ref-a'],
        );
        final id2 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do other stuff'},
          targetRefs: ['ref-a'],
        );

        expect(id1, isNot(equals(id2)));
      });

      test('differs when targetRefs change', () {
        final id1 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff'},
          targetRefs: ['ref-a'],
        );
        final id2 = RunKeyFactory.actionStableId(
          toolName: 'createTask',
          args: {'title': 'Do stuff'},
          targetRefs: ['ref-c'],
        );

        expect(id1, isNot(equals(id2)));
      });

      test('handles empty args and targetRefs', () {
        final id = RunKeyFactory.actionStableId(
          toolName: 'noOp',
          args: {},
          targetRefs: [],
        );

        expect(id, hasLength(64));
        expect(id, matches(RegExp(r'^[a-f0-9]{64}$')));
      });

      test('produces identical key regardless of args key order', () {
        final id1 = RunKeyFactory.actionStableId(
          toolName: 'updateTask',
          args: {'title': 'Fix bug', 'priority': 1, 'estimate': 30},
          targetRefs: ['ref-a'],
        );
        final id2 = RunKeyFactory.actionStableId(
          toolName: 'updateTask',
          args: {'estimate': 30, 'title': 'Fix bug', 'priority': 1},
          targetRefs: ['ref-a'],
        );

        expect(
          id1,
          equals(id2),
          reason: 'JSON key order must not affect the stable ID',
        );
      });
    });

    glados.Glados(
      glados.any.runKeyCanonicalizationScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated canonicalization invariants', (scenario) {
      final timestamp = _fixedTime.add(Duration(seconds: scenario.seed));
      final subscriptionKey = RunKeyFactory.forSubscription(
        agentId: 'agent-${scenario.seed}',
        subscriptionId: 'subscription-${scenario.seed}',
        batchTokens: scenario.tokenSet,
        wakeCounter: scenario.seed,
        timestamp: timestamp,
      );
      final subscriptionKeyFromReorderedTokens = RunKeyFactory.forSubscription(
        agentId: 'agent-${scenario.seed}',
        subscriptionId: 'subscription-${scenario.seed}',
        batchTokens: scenario.tokenSet.toList().reversed.toSet(),
        wakeCounter: scenario.seed,
        timestamp: timestamp,
      );

      expect(
        subscriptionKeyFromReorderedTokens,
        subscriptionKey,
        reason: '$scenario',
      );
      expect(subscriptionKey, hasLength(64), reason: '$scenario');
      expect(subscriptionKey, matches(RegExp(r'^[a-f0-9]{64}$')));

      final stableActionId = RunKeyFactory.actionStableId(
        toolName: 'generated_tool',
        args: scenario.argsInOriginalOrder,
        targetRefs: scenario.targetRefs,
      );
      final stableActionIdFromReorderedInputs = RunKeyFactory.actionStableId(
        toolName: 'generated_tool',
        args: scenario.argsInDifferentOrder,
        targetRefs: scenario.targetRefs.reversed.toList(),
      );

      expect(
        stableActionIdFromReorderedInputs,
        stableActionId,
        reason: '$scenario',
      );
      expect(stableActionId, hasLength(64), reason: '$scenario');
      expect(
        RunKeyFactory.operationId(
          runKey: subscriptionKey,
          actionStableId: stableActionId,
        ),
        hasLength(64),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}
