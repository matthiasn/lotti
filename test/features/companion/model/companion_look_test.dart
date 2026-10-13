import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';

void main() {
  test('every look has its own id', () {
    final ids = CompanionLook.all.map((l) => l.id).toSet();
    expect(ids, {'grandma', 'grandma_stage', 'grandma_rock'});
  });

  test('the stage look keeps her face and changes only the outfit', () {
    const base = CompanionPalette();
    final stage = CompanionLook.grandmaStage.palette;
    expect(stage.skin, base.skin);
    expect(stage.hair, base.hair);
    expect(stage.iris, base.iris);
    expect(stage.dress, isNot(base.dress));
    expect(stage.cardigan, isNot(base.cardigan));
    expect(CompanionLook.grandmaStage.glasses, isTrue);
  });

  test('the rock look swaps the glasses for sunglasses and adds the props', () {
    const rock = CompanionLook.grandmaRock;
    expect(rock.glasses, isFalse);
    expect(rock.sunglasses, isTrue);
    expect(rock.beret && rock.beads && rock.glove, isTrue);
    expect(rock.earring, EarringKind.disc);
    expect(rock.palette.lips, isNot(const CompanionPalette().lips));
  });

  test('the everyday look wears none of the props', () {
    const g = CompanionLook.grandma;
    expect(g.sunglasses || g.beret || g.beads || g.glove, isFalse);
    expect(g.earring, EarringKind.pearl);
  });
}
