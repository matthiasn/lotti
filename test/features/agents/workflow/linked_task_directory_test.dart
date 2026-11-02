import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_input.dart';
import 'package:lotti/features/agents/workflow/linked_task_directory.dart';

final _base = DateTime(2024, 3);

LinkedTaskRow _row(
  String id, {
  String status = 'OPEN',
  int day = 0,
  String? title,
  String? oneLiner,
  int labelCount = 0,
}) {
  final context = AiLinkedTaskContext(
    id: id,
    title: title ?? 'Task $id',
    status: status,
    statusSince: _base,
    priority: 'P2',
    estimate: '01:00',
    timeSpent: '00:30',
    createdAt: _base.add(Duration(days: day)),
    labels: [
      for (var i = 0; i < labelCount; i++) {'id': 'label-$i', 'name': 'L$i'},
    ],
  );
  return (
    task: context,
    row: {
      ...context.toJson(),
      'summaryStatus': oneLiner == null ? 'none' : 'present',
      LinkedTaskDirectory.oneLinerKey: ?oneLiner,
    },
  );
}

List<String> _ids(Map<String, dynamic> decoded, String side) => [
  for (final row in decoded[side] as List<dynamic>)
    (row as Map<String, dynamic>)['id'] as String,
];

Map<String, dynamic> _decode(LinkedTaskDirectory directory) =>
    jsonDecode(directory.json) as Map<String, dynamic>;

void main() {
  test('no linked tasks: no section and nothing to read', () {
    final directory = LinkedTaskDirectory.build(linkedFrom: [], linkedTo: []);

    expect(directory.json, '{}');
    expect(directory.taskIds, isEmpty);
    expect(directory.omittedCount, 0);
  });

  test('lists every task when they fit, one row per line, in arrival '
      'order, and lists their ids', () {
    final directory = LinkedTaskDirectory.build(
      linkedFrom: [
        _row('child-old', oneLiner: 'Waiting on parts'),
        _row('child-new', day: 5, status: 'DONE'),
      ],
      linkedTo: [_row('parent')],
    );
    final decoded = _decode(directory);

    expect(_ids(decoded, 'linked_from'), ['child-old', 'child-new']);
    expect(_ids(decoded, 'linked_to'), ['parent']);
    expect(decoded.containsKey('omitted'), isFalse);
    expect(directory.taskIds, {'child-old', 'child-new', 'parent'});
    expect(directory.omittedCount, 0);
    final first = (decoded['linked_from'] as List).first as Map;
    expect(first[LinkedTaskDirectory.oneLinerKey], 'Waiting on parts');
    // Each row is a single line: the section grows by rows, not by fields.
    expect(directory.json.split('\n'), hasLength(3 + 2 + 3 + 1));
  });

  test('caps the rows, choosing open tasks before closed and newer before '
      'older', () {
    final directory = LinkedTaskDirectory.build(
      linkedFrom: [
        for (var i = 0; i < 10; i++) _row('done-$i', status: 'DONE', day: 100),
        for (var i = 0; i < 25; i++) _row('open-$i', day: i),
        // Closed and older than every DONE task: the first to go.
        _row('rejected', status: 'REJECTED'),
      ],
      linkedTo: [],
    );
    final decoded = _decode(directory);
    final listed = _ids(decoded, 'linked_from');

    expect(listed, hasLength(LinkedTaskDirectory.maxRows));
    // Every open task is in, and the newest closed ones fill the rest.
    expect(listed.where((id) => id.startsWith('open-')), hasLength(25));
    // Of the closed, the five newest by id (all DONE on day 100) stay.
    expect(listed.where((id) => !id.startsWith('open-')), [
      'done-5',
      'done-6',
      'done-7',
      'done-8',
      'done-9',
    ]);
    expect(directory.omittedCount, 36 - LinkedTaskDirectory.maxRows);
    expect((decoded['omitted'] as Map)['count'], directory.omittedCount);
    expect(
      (decoded['omitted'] as Map)['note'],
      LinkedTaskDirectory.omittedNote(directory.omittedCount),
    );
    // Chosen rows keep the order they arrived in.
    expect(listed.first, 'done-5');
    expect(listed[5], 'open-0');
    expect(directory.taskIds, listed.toSet());
  });

  test('among equally open tasks the newest win, the id breaking ties', () {
    final directory = LinkedTaskDirectory.build(
      linkedFrom: [
        for (var i = 0; i < 40; i++) _row('t-${i.toString().padLeft(2, '0')}'),
      ],
      linkedTo: [],
    );

    // Same day for all: the highest ids are kept, deterministically.
    expect(directory.taskIds, {
      for (var i = 10; i < 40; i++) 't-${i.toString().padLeft(2, '0')}',
    });
  });

  test('stays within the character budget however many tasks are linked, '
      'and how large they are', () {
    for (final count in [1, 5, 29, 30, 31, 60, 200, 1000]) {
      for (final labelCount in [0, 3, 40]) {
        final directory = LinkedTaskDirectory.build(
          linkedFrom: [
            for (var i = 0; i < count; i++)
              _row(
                'from-$i',
                day: i,
                title: 'Linked work item $i ' * (1 + i % 12),
                oneLiner: 'Progress on item $i. ' * (1 + i % 20),
                labelCount: labelCount,
                status: i.isEven ? 'OPEN' : 'DONE',
              ),
          ],
          linkedTo: [
            for (var i = 0; i < count ~/ 3; i++)
              _row('to-$i', day: i, labelCount: labelCount),
          ],
        );
        final decoded = _decode(directory);
        final listed = [
          ..._ids(decoded, 'linked_from'),
          ..._ids(decoded, 'linked_to'),
        ];
        final reason = 'count $count, labels $labelCount';

        expect(
          directory.json.length,
          lessThanOrEqualTo(LinkedTaskDirectory.charBudget),
          reason: reason,
        );
        expect(
          listed.length,
          lessThanOrEqualTo(LinkedTaskDirectory.maxRows),
          reason: reason,
        );
        expect(
          listed.length + directory.omittedCount,
          count + count ~/ 3,
          reason: reason,
        );
        expect(directory.taskIds, listed.toSet(), reason: reason);
        expect(decoded.containsKey('omitted'), directory.omittedCount > 0);
      }
    }
  });

  test('clips long titles and one-liners, leaving the rest of the row and '
      'the input untouched', () {
    final input = _row(
      'long',
      title: 'T' * 500,
      oneLiner: 'O' * 500,
      labelCount: 2,
    );
    final directory = LinkedTaskDirectory.build(
      linkedFrom: [input],
      linkedTo: [],
    );
    final row = (_decode(directory)['linked_from'] as List).single as Map;

    expect(row['title'], '${'T' * (LinkedTaskDirectory.maxTitleChars - 1)}…');
    expect(
      row[LinkedTaskDirectory.oneLinerKey],
      '${'O' * (LinkedTaskDirectory.maxOneLinerChars - 1)}…',
    );
    expect(row['labels'], hasLength(2));
    expect(row['priority'], 'P2');
    expect(input.row['title'], 'T' * 500);
  });

  test('skips a row too large for the budget but still lists smaller ones '
      'after it', () {
    final directory = LinkedTaskDirectory.build(
      linkedFrom: [
        // Newest, so ranked first, and far over the budget on its own.
        _row('huge', day: 9, labelCount: 2000),
        _row('small'),
      ],
      linkedTo: [],
    );

    expect(directory.taskIds, {'small'});
    expect(directory.omittedCount, 1);
    expect(
      directory.json.length,
      lessThanOrEqualTo(LinkedTaskDirectory.charBudget),
    );
  });

  test('the omitted note reads in the singular and the plural', () {
    expect(
      LinkedTaskDirectory.omittedNote(1),
      startsWith(
        '1 more linked task '
        'is not listed',
      ),
    );
    expect(
      LinkedTaskDirectory.omittedNote(4),
      startsWith(
        '4 more linked tasks '
        'are not listed',
      ),
    );
    expect(
      LinkedTaskDirectory.omittedNote(4),
      contains('Their ids are not available in this wake.'),
    );
  });
}
