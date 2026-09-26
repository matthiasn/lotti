import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/model/membership_list.dart';

/// Membership ids drawn from a small pool, so generated lists overlap.
List<String> _ids(List<int> seeds) => [for (final seed in seeds) 'id-$seed'];

/// [_ids] without repeats, first occurrence kept — a stored membership list
/// never lists an id twice.
List<String> _uniqueIds(List<int> seeds) => _ids(seeds).toSet().toList();

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

  group('properties', () {
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
