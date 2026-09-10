import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_wall_swap.dart';

void main() {
  late PlazaWallSwap swap;

  setUp(() => swap = PlazaWallSwap());

  test('a world with no walls yet asks for the sky it wants', () {
    expect(
      swap.request(wanted: PlazaSkyMode.night, attached: null),
      PlazaSkyMode.night,
    );
    expect(swap.inFlight, PlazaSkyMode.night);
  });

  test('the sky already on the walls needs nothing', () {
    expect(
      swap.request(wanted: PlazaSkyMode.night, attached: PlazaSkyMode.night),
      isNull,
    );
    expect(swap.inFlight, isNull);
  });

  test('switching sky asks for that sky exactly once', () {
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night),
      PlazaSkyMode.day,
    );
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night),
      isNull,
      reason: 'the same set must not be painted twice over',
    );
  });

  test('switching back does not cancel the set already on its way', () {
    swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night);
    expect(
      swap.request(wanted: PlazaSkyMode.night, attached: PlazaSkyMode.night),
      isNull,
      reason: 'night is already on the walls; nothing to load',
    );
    expect(
      swap.inFlight,
      PlazaSkyMode.day,
      reason: 'the day paint is still running and will settle itself',
    );
  });

  test('a dropped set can be asked for again', () {
    // The regression: switch to day, switch back before it lands, then
    // switch to day again. The dropped load used to leave its mode marked
    // as in flight forever, so nothing was ever scheduled and the district
    // wore night windows under a day sky until the page was rebuilt.
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night),
      PlazaSkyMode.day,
    );
    swap
      ..request(wanted: PlazaSkyMode.night, attached: PlazaSkyMode.night)
      ..settled(PlazaSkyMode.day); // arrived unwanted, dropped
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night),
      PlazaSkyMode.day,
    );
  });

  test('a failed load leaves its sky askable', () {
    swap
      ..request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night)
      ..settled(PlazaSkyMode.day); // threw
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night),
      PlazaSkyMode.day,
      reason: 'one failed paint must not disable that sky for the session',
    );
  });

  test('an attached set stops being asked for', () {
    swap
      ..request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night)
      ..settled(PlazaSkyMode.day);
    expect(
      swap.request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.day),
      isNull,
    );
    expect(swap.inFlight, isNull);
  });

  test('settling a set that is not in flight changes nothing', () {
    swap
      ..request(wanted: PlazaSkyMode.day, attached: PlazaSkyMode.night)
      ..settled(PlazaSkyMode.night);
    expect(
      swap.inFlight,
      PlazaSkyMode.day,
      reason: 'a locale reload settling night must not free the day marker',
    );
  });
}
