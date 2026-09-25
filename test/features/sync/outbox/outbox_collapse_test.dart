import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_collapse.dart';
import 'package:lotti/features/sync/vector_clock.dart';

var _nextId = 0;

CollapseCandidate _candidate(
  SyncMessage message, {
  String? entryId = 'e',
  String? filePath,
  int? id,
}) => CollapseCandidate.decode(
  OutboxItem(
    id: id ?? ++_nextId,
    createdAt: DateTime(2026, 9, 25),
    updatedAt: DateTime(2026, 9, 25),
    status: 0,
    retries: 0,
    message: jsonEncode(message.toJson()),
    subject: 's',
    filePath: filePath,
    outboxEntryId: entryId,
    priority: 1,
  ),
);

SyncEntryLink _link(Map<String, int>? clock) =>
    SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-1',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2026, 9, 25),
            updatedAt: DateTime(2026, 9, 25),
            vectorClock: clock == null ? null : VectorClock(clock),
          ),
          status: SyncEntryStatus.update,
        )
        as SyncEntryLink;

SyncAgentLink _agentLink(int counter) =>
    SyncMessage.agentLink(
          agentLink: AgentLink.agentTask(
            id: 'al-1',
            fromId: 'agent',
            toId: 'task',
            createdAt: DateTime(2026, 9, 25),
            updatedAt: DateTime(2026, 9, 25),
            vectorClock: VectorClock({'h': counter}),
          ),
          status: SyncEntryStatus.update,
        )
        as SyncAgentLink;

void main() {
  group('collapseKeyOf', () {
    test('entity payloads collapse by their outbox entry id', () {
      expect(collapseKeyOf(_candidate(_link({'h': 1}))), 'e');
      expect(collapseKeyOf(_candidate(_agentLink(1))), 'e');
      expect(
        collapseKeyOf(
          _candidate(
            const SyncMessage.configFlag(
              name: 'f',
              description: 'd',
              status: true,
            ),
          ),
        ),
        'e',
      );
    });

    test('rows without an entry id, and payloads that do not collapse, '
        'are sent row by row', () {
      expect(collapseKeyOf(_candidate(_link({'h': 1}), entryId: null)), isNull);
      expect(
        collapseKeyOf(
          _candidate(
            const SyncMessage.aiConfigDelete(id: 'x'),
          ),
        ),
        isNull,
      );
    });
  });

  group('newestOf / supersededBy', () {
    test('a dominating clock wins over a later enqueue', () {
      final newer = _candidate(_link({'h': 3}), id: 1);
      final older = _candidate(_link({'h': 2}), id: 2);
      expect(newestOf([newer, older]), same(newer));
      expect(supersededBy(older, newer), isTrue);
      expect(supersededBy(newer, older), isFalse);
    });

    test('concurrent or invalid clocks fall back to enqueue order, and are '
        'never folded into each other', () {
      final a = _candidate(_link({'a': 1}), id: 1);
      final b = _candidate(_link({'b': 1}), id: 2);
      expect(newestOf([a, b]), same(b));
      expect(supersededBy(a, b), isFalse);

      final invalid = _candidate(_link({'h': -1}), id: 3);
      final valid = _candidate(_link({'h': 1}), id: 4);
      expect(newestOf([invalid, valid]), same(valid));
      expect(supersededBy(invalid, valid), isFalse);
    });

    test('a row without a clock is ordered by enqueue order', () {
      final early = _candidate(_link(null), id: 1);
      final late = _candidate(_link({'h': 1}), id: 2);
      expect(newestOf([early, late]), same(late));
      expect(supersededBy(early, late), isTrue);
    });
  });

  group('collapsedMessage', () {
    test('a single member is sent as it is', () {
      final only = _candidate(_link({'h': 1}));
      expect(collapsedMessage(only, [only]), same(only.message));
    });

    test('link and agent-link sends cover every folded counter', () {
      final links = [
        for (final c in [1, 2]) _candidate(_link({'h': c})),
      ];
      final link = collapsedMessage(links.last, links) as SyncEntryLink;
      expect(link.coveredVectorClocks, [
        const VectorClock({'h': 1}),
      ]);

      final agentLinks = [
        for (final c in [4, 5]) _candidate(_agentLink(c)),
      ];
      final agentLink =
          collapsedMessage(agentLinks.last, agentLinks) as SyncAgentLink;
      expect(agentLink.coveredVectorClocks, [
        const VectorClock({'h': 4}),
      ]);
    });

    test('a clockless payload keeps the newest message unchanged', () {
      final flags = [
        for (final status in [true, false])
          _candidate(
            SyncMessage.configFlag(name: 'f', description: 'd', status: status),
          ),
      ];
      expect(collapsedMessage(flags.last, flags), same(flags.last.message));
    });
  });
}
