import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/membership_list.dart';

/// Membership ids drawn from a small pool, so generated lists overlap.
List<String> _ids(List<int> seeds) => [for (final seed in seeds) 'id-$seed'];

/// [_ids] without repeats, first occurrence kept — a stored membership list
/// never lists an id twice.
List<String> _uniqueIds(List<int> seeds) => _ids(seeds).toSet().toList();

Metadata _meta(String id, {DateTime? date, bool deleted = false}) {
  final at = date ?? DateTime(2024, 3, 15);
  return Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    deletedAt: deleted ? at : null,
  );
}

/// An item naming [checklists] in its back-link.
ChecklistItem _item(
  String id,
  List<String> checklists, {
  DateTime? date,
  bool deleted = false,
}) => ChecklistItem(
  meta: _meta(id, date: date, deleted: deleted),
  data: ChecklistItemData(
    title: id,
    isChecked: false,
    linkedChecklists: checklists,
  ),
);

Checklist _checklist(String id, List<String> items, {bool deleted = false}) =>
    Checklist(
      meta: _meta(id, deleted: deleted),
      data: ChecklistData(
        title: id,
        linkedChecklistItems: items,
        linkedTasks: const ['task'],
      ),
    );

void main() {
  group('withMember', () {
    test('appends an id that is not listed yet', () {
      expect(withMember(['a', 'b'], 'c'), ['a', 'b', 'c']);
    });

    test('leaves the list unchanged when the id is listed already', () {
      final ids = ['a', 'b'];

      final result = withMember(ids, 'a');

      expect(result, ['a', 'b']);
      expect(result, same(ids));
    });

    test('adding the same id twice lists it once', () {
      expect(withMember(withMember(['a'], 'b'), 'b'), ['a', 'b']);
    });
  });

  group('withoutMember', () {
    test('removes the id and keeps the order of the others', () {
      expect(withoutMember(['a', 'b', 'c'], 'b'), ['a', 'c']);
    });

    test('is a no-op for an id that is not listed', () {
      expect(withoutMember(['a', 'b'], 'x'), ['a', 'b']);
    });
  });

  group('inVisibleOrder', () {
    test('applies the order the screen shows', () {
      expect(inVisibleOrder(['a', 'b', 'c'], ['c', 'a', 'b']), [
        'c',
        'a',
        'b',
      ]);
    });

    test('drops a visible id that is no longer stored', () {
      expect(inVisibleOrder(['a', 'c'], ['c', 'b', 'a']), ['c', 'a']);
    });

    test(
      'keeps stored ids the screen does not show after the ordered ones, '
      'in stored order',
      () {
        expect(inVisibleOrder(['x', 'a', 'y', 'b'], ['b', 'a']), [
          'b',
          'a',
          'x',
          'y',
        ]);
      },
    );

    test('an empty visible list keeps the stored list as it is', () {
      expect(inVisibleOrder(['a', 'b'], const []), ['a', 'b']);
    });
  });

  group('joinMembers', () {
    test("keeps the kept side's order, then the ids only the other lists", () {
      expect(joinMembers(['b', 'a'], ['a', 'c', 'b', 'd']), [
        'b',
        'a',
        'c',
        'd',
      ]);
    });

    test('an empty side leaves the other as it is', () {
      expect(joinMembers(const [], ['a', 'b']), ['a', 'b']);
      expect(joinMembers(['a', 'b'], const []), ['a', 'b']);
    });
  });

  group('which checklist shows an item', () {
    test('homeChecklistId is the first checklist the back-link names', () {
      expect(homeChecklistId(_item('i', ['c2', 'c1'])), 'c2');
      expect(homeChecklistId(_item('i', const [])), isNull);
    });

    test('isShownIn: a live item naming the checklist, or naming none', () {
      expect(isShownIn(_item('i', ['c1']), 'c1'), isTrue);
      expect(isShownIn(_item('i', ['c2']), 'c1'), isFalse);
      expect(isShownIn(_item('i', const []), 'c1'), isTrue);
      expect(isShownIn(_item('i', ['c1'], deleted: true), 'c1'), isFalse);
      expect(isShownIn(_checklist('c1', const []), 'c1'), isFalse);
      expect(isShownIn(null, 'c1'), isFalse);
    });

    test('checklistShowsItem: an item naming none needs the list to hold '
        'it, and a deleted checklist shows nothing', () {
      final named = _item('named', ['c1']);
      final legacy = _item('legacy', const []);
      final listing = _checklist('c1', ['legacy']);

      expect(checklistShowsItem(_checklist('c1', const []), named), isTrue);
      expect(checklistShowsItem(_checklist('c1', const []), legacy), isFalse);
      expect(checklistShowsItem(listing, legacy), isTrue);
      expect(checklistShowsItem(_checklist('c2', ['named']), named), isFalse);
      expect(
        checklistShowsItem(_checklist('c1', ['named'], deleted: true), named),
        isFalse,
      );
      expect(checklistShowsItem(listing, null), isFalse);
    });
  });

  group('shownItemIds', () {
    test(
      'shows the listed items naming the checklist in list order, then '
      'those naming it that it does not list yet, oldest first',
      () {
        final items = <String, JournalEntity?>{
          'b': _item('b', ['c1']),
          'a': _item('a', ['c1']),
          // Moved away by another device: listed here, shown there.
          'moved': _item('moved', ['c2']),
          // Deleted, and a listed id with no row at all.
          'gone': _item('gone', ['c1'], deleted: true),
          // Named but not listed yet: its listing has not arrived.
          'late-new': _item('late-new', ['c1'], date: DateTime(2024, 3, 2)),
          'late-old': _item('late-old', ['c1'], date: DateTime(2024, 2, 28)),
          'late-gone': _item('late-gone', ['c1'], deleted: true),
          // Legacy: names no checklist, shown where listed.
          'legacy': _item('legacy', const []),
        };

        expect(
          shownItemIds(
            checklistId: 'c1',
            listed: ['b', 'moved', 'missing', 'a', 'gone', 'legacy', 'b'],
            items: items,
          ),
          ['b', 'a', 'legacy', 'late-old', 'late-new'],
        );
      },
    );

    test('two items of one date follow in id order', () {
      expect(
        shownItemIds(
          checklistId: 'c1',
          listed: const [],
          items: {
            'y': _item('y', ['c1']),
            'x': _item('x', ['c1']),
          },
        ),
        ['x', 'y'],
      );
    });
  });

  group('properties', () {
    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 6)),
      glados.any.list(glados.any.intInRange(0, 6)),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'however two checklists list them, every live item naming one of them '
      'is shown by that one alone, once — so none is counted twice '
      '(ChecklistReplication.tla, ShownOnce)',
      (firstSeeds, secondSeeds) {
        // Item n names c1 when n is even, c2 when n is odd.
        final items = <String, JournalEntity?>{
          for (var n = 0; n <= 6; n++)
            'id-$n': _item('id-$n', [if (n.isEven) 'c1' else 'c2']),
        };
        final first = shownItemIds(
          checklistId: 'c1',
          listed: _ids(firstSeeds),
          items: items,
        );
        final second = shownItemIds(
          checklistId: 'c2',
          listed: _ids(secondSeeds),
          items: items,
        );

        final reason = 'c1=$firstSeeds c2=$secondSeeds';
        expect(
          [...first, ...second]..sort(),
          items.keys.toList()..sort(),
          reason: reason,
        );
        expect(
          first.every((id) => int.parse(id.substring(3)).isEven),
          isTrue,
          reason: reason,
        );
        expect(
          second.every((id) => int.parse(id.substring(3)).isOdd),
          isTrue,
          reason: reason,
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 12)),
      glados.any.list(glados.any.intInRange(0, 12)),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'inVisibleOrder keeps exactly the stored ids, each once, visible ones '
      'first in visible order, the rest in stored order',
      (storedSeeds, visibleSeeds) {
        final stored = _uniqueIds(storedSeeds);
        final visible = _ids(visibleSeeds);

        final result = inVisibleOrder(stored, visible);

        final reason = 'stored=$stored visible=$visible result=$result';
        expect(result.toSet(), stored.toSet(), reason: reason);
        expect(result, hasLength(stored.length), reason: reason);

        final shown = visible.toSet().where(stored.contains).toList();
        expect(result.take(shown.length), shown, reason: reason);
        expect(
          result.skip(shown.length),
          stored.where((id) => !visible.contains(id)),
          reason: reason,
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 12)),
      glados.any.intInRange(0, 12),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'withMember lists the id exactly once and withoutMember not at all, '
      'leaving the other ids in place',
      (storedSeeds, seed) {
        final stored = _uniqueIds(storedSeeds);
        final id = 'id-$seed';
        final others = stored.where((other) => other != id).toList();

        final added = withMember(stored, id);
        final removed = withoutMember(stored, id);

        final reason = 'stored=$stored id=$id';
        expect(
          added.where((other) => other == id),
          hasLength(1),
          reason: reason,
        );
        expect(added.where((other) => other != id), others, reason: reason);
        expect(removed, others, reason: reason);
      },
      tags: 'glados',
    );
  });
}
