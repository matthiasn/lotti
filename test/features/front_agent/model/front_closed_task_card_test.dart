import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';

void main() {
  final completed = FrontClosedTaskCard(
    id: 't1',
    title: 'Count the eggs',
    closedAt: DateTime.utc(2026, 11, 7, 10),
    categoryId: 'colony',
  );
  final rejectedReopened = FrontClosedTaskCard(
    id: 't2',
    title: 'Sweep the ice',
    closedAt: DateTime.utc(2026, 11, 8, 11),
    rejected: true,
    reopened: true,
  );

  test('stores only what is set, in UTC, and reads it back the same', () {
    expect(completed.toJson(), {
      'id': 't1',
      'title': 'Count the eggs',
      'closedAt': '2026-11-07T10:00:00.000Z',
      'categoryId': 'colony',
    });
    expect(rejectedReopened.toJson(), {
      'id': 't2',
      'title': 'Sweep the ice',
      'closedAt': '2026-11-08T11:00:00.000Z',
      'rejected': true,
      'reopened': true,
    });
    expect(
      FrontClosedTaskCard.listFromJson([
        completed.toJson(),
        rejectedReopened.toJson(),
      ]),
      [completed, rejectedReopened],
    );
  });

  test('a local close time is the same moment once stored', () {
    final local = DateTime(2026, 11, 7, 23, 30);
    final card = FrontClosedTaskCard(id: 't', title: 'T', closedAt: local);

    final read = FrontClosedTaskCard.fromJson(card.toJson())!;

    expect(read.closedAt.isAtSameMomentAs(local), isTrue);
    expect(read, card);
  });

  test('equal cards hash alike whatever the zone of their moment, and a '
      'card says how it closed', () {
    final same = FrontClosedTaskCard(
      id: 't1',
      title: 'Count the eggs',
      closedAt: DateTime.utc(2026, 11, 7, 10).toLocal(),
      categoryId: 'colony',
    );

    expect(same, completed);
    expect(same.hashCode, completed.hashCode);
    expect({completed, same, rejectedReopened}, hasLength(2));
    expect(
      completed.toString(),
      'FrontClosedTaskCard(t1, completed 2026-11-07T10:00:00.000Z)',
    );
    expect(
      rejectedReopened.toString(),
      'FrontClosedTaskCard(t2, rejected 2026-11-08T11:00:00.000Z, reopened)',
    );
  });

  test('a card or list this build cannot read is dropped, never thrown', () {
    expect(FrontClosedTaskCard.fromJson(null), isNull);
    expect(FrontClosedTaskCard.fromJson({'id': 't', 'title': 'T'}), isNull);
    expect(
      FrontClosedTaskCard.fromJson({
        'id': 't',
        'title': 7,
        'closedAt': '2026-11-07T10:00:00.000Z',
      }),
      isNull,
    );
    expect(
      FrontClosedTaskCard.fromJson({
        'id': 't',
        'title': 'T',
        'closedAt': 'soon',
      }),
      isNull,
    );
    expect(FrontClosedTaskCard.listFromJson('soon'), isEmpty);
    expect(
      FrontClosedTaskCard.listFromJson([
        {'id': 'x'},
        completed.toJson(),
      ]),
      [completed],
    );
  });
}
