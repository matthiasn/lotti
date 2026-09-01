import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';

void main() {
  group('LockdownState', () {
    test('inactive state allows everything and leaves filters untouched', () {
      const state = LockdownState.inactive;

      expect(state.isActive, isFalse);
      expect(state.allows('work'), isTrue);
      expect(state.allows(null), isTrue);
      expect(state.allows(''), isTrue);
      expect(state.restrict({'a', 'b'}), {'a', 'b'});
      expect(state.restrict(const {}), isEmpty);
    });

    test('active state allows only the locked categories', () {
      const state = LockdownState(categoryIds: {'work'});

      expect(state.isActive, isTrue);
      expect(state.allows('work'), isTrue);
      expect(state.allows('health'), isFalse);
      expect(state.allows(null), isFalse, reason: 'unassigned never leaks');
      expect(state.allows(''), isFalse, reason: 'the unassigned sentinel');
    });

    test('restrict keeps the overlap and never widens beyond the lock', () {
      const state = LockdownState(categoryIds: {'work', 'side'});

      expect(state.restrict({'work'}), {'work'});
      expect(state.restrict({'work', 'health'}), {'work'});
    });

    test(
      'restrict falls back to the whole locked set when nothing overlaps',
      () {
        const state = LockdownState(categoryIds: {'work', 'side'});

        // Empty selection means "all categories" downstream — under lockdown it
        // must resolve to the locked set, never to everything.
        expect(state.restrict(const {}), {'work', 'side'});
        expect(state.restrict({'health'}), {'work', 'side'});
        expect(state.restrict({''}), {'work', 'side'});
      },
    );

    test('equality is by category set, regardless of order or identity', () {
      expect(
        const LockdownState(categoryIds: {'a', 'b'}),
        const LockdownState(categoryIds: {'b', 'a'}),
      );
      expect(
        const LockdownState(categoryIds: {'a', 'b'}).hashCode,
        const LockdownState(categoryIds: {'b', 'a'}).hashCode,
      );
      expect(
        const LockdownState(categoryIds: {'a'}),
        isNot(const LockdownState(categoryIds: {'b'})),
      );
    });
  });
}
