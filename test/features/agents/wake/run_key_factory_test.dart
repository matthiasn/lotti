import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';

/// Helper to compute SHA-256 the same way RunKeyFactory does internally.
String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

void main() {
  group('RunKeyFactory', () {
    group('forSubscription', () {
      test('produces deterministic key for same inputs', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a', 'tok-b'},
          wakeCounter: 3,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-b', 'tok-a'},
          wakeCounter: 3,
        );

        expect(key1, equals(key2),
            reason: 'Token order must not affect the key');
      });

      test('differs when agentId changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-2',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when subscriptionId changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-2',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when batchTokens change', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-b'},
          wakeCounter: 0,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when wakeCounter changes', () {
        final key1 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 1,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('produces valid SHA-256 hex string', () {
        final key = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-a'},
          wakeCounter: 0,
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
          '$agentId|$subscriptionId|$batchTokensHash|$wakeCounter',
        );

        final actual = RunKeyFactory.forSubscription(
          agentId: agentId,
          subscriptionId: subscriptionId,
          batchTokens: batchTokens,
          wakeCounter: wakeCounter,
        );

        expect(actual, equals(expected));
      });
    });

    group('forTimer', () {
      test('produces deterministic key for same inputs', () {
        final scheduledAt = DateTime(2024, 3, 15, 10, 30);
        final key1 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-1',
          scheduledAt: scheduledAt,
        );
        final key2 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-1',
          scheduledAt: scheduledAt,
        );

        expect(key1, equals(key2));
      });

      test('differs when timerId changes', () {
        final scheduledAt = DateTime(2024, 3, 15, 10, 30);
        final key1 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-1',
          scheduledAt: scheduledAt,
        );
        final key2 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-2',
          scheduledAt: scheduledAt,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when scheduledAt changes', () {
        final key1 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-1',
          scheduledAt: DateTime(2024, 3, 15, 10, 30),
        );
        final key2 = RunKeyFactory.forTimer(
          agentId: 'agent-1',
          timerId: 'timer-1',
          scheduledAt: DateTime(2024, 3, 15, 11, 30),
        );

        expect(key1, isNot(equals(key2)));
      });

      test('matches manual SHA-256 computation', () {
        const agentId = 'agent-1';
        const timerId = 'timer-1';
        final scheduledAt = DateTime(2024, 3, 15, 10, 30);
        final expected =
            _sha256('$agentId|$timerId|${scheduledAt.toIso8601String()}');

        final actual = RunKeyFactory.forTimer(
          agentId: agentId,
          timerId: timerId,
          scheduledAt: scheduledAt,
        );

        expect(actual, equals(expected));
      });
    });

    group('forUserInitiated', () {
      test('produces deterministic key for same inputs', () {
        final key1 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-1',
          turnId: 'turn-1',
        );
        final key2 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-1',
          turnId: 'turn-1',
        );

        expect(key1, equals(key2));
      });

      test('differs when sessionId changes', () {
        final key1 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-1',
          turnId: 'turn-1',
        );
        final key2 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-2',
          turnId: 'turn-1',
        );

        expect(key1, isNot(equals(key2)));
      });

      test('differs when turnId changes', () {
        final key1 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-1',
          turnId: 'turn-1',
        );
        final key2 = RunKeyFactory.forUserInitiated(
          agentId: 'agent-1',
          sessionId: 'session-1',
          turnId: 'turn-2',
        );

        expect(key1, isNot(equals(key2)));
      });

      test('matches manual SHA-256 computation', () {
        const agentId = 'agent-1';
        const sessionId = 'session-1';
        const turnId = 'turn-1';
        final expected = _sha256('$agentId|$sessionId|$turnId');

        final actual = RunKeyFactory.forUserInitiated(
          agentId: agentId,
          sessionId: sessionId,
          turnId: turnId,
        );

        expect(actual, equals(expected));
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

        expect(id1, equals(id2),
            reason: 'targetRefs order must not affect the key');
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
    });
  });
}
