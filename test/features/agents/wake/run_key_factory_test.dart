import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';

final _fixedTime = DateTime(2024, 3, 15, 10, 30);

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
          timestamp: _fixedTime,
        );
        final key2 = RunKeyFactory.forSubscription(
          agentId: 'agent-1',
          subscriptionId: 'sub-1',
          batchTokens: {'tok-b', 'tok-a'},
          wakeCounter: 3,
          timestamp: _fixedTime,
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

        expect(id1, equals(id2),
            reason: 'JSON key order must not affect the stable ID');
      });
    });
  });
}
