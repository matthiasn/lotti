import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late SettingsDb db;
  late MockDomainLogger logger;

  setUp(() {
    db = SettingsDb(inMemoryDatabase: true);
    logger = MockDomainLogger();
  });
  tearDown(() => db.close());

  ProviderContainer container([SettingsDb? settings]) {
    final c = ProviderContainer(
      overrides: [
        settingsDbProvider.overrideWithValue(settings ?? db),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Reads the customization and lets its load from storage land.
  Future<CompanionCustomization> loaded(ProviderContainer c) async {
    final sub = c.listen(companionCustomizationProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    return c.read(companionCustomizationProvider);
  }

  test('starts as Lotti, with nothing stored', () async {
    expect(await loaded(container()), const CompanionCustomization());
  });

  test('a change is stored, and comes back in the next session', () async {
    const custom = CompanionCustomization(
      skinTone: CompanionSkinTone.tone4,
      hairStyle: CompanionHairStyle.bob,
      hairColour: CompanionHairColour.pink,
      outfitId: 'grandma_garden',
    );
    final first = container();
    await loaded(first);
    first.read(companionCustomizationProvider.notifier).set(custom);
    expect(first.read(companionCustomizationProvider), custom);
    await pumpEventQueue();

    expect(
      jsonDecode((await db.itemByKey(companionCustomizationKey))!),
      custom.toJson(),
    );
    expect(await loaded(container()), custom);
  });

  test('a change made before the load lands is not undone by it', () async {
    await db.saveSettingsItem(
      companionCustomizationKey,
      jsonEncode(
        const CompanionCustomization(
          hairStyle: CompanionHairStyle.afro,
        ).toJson(),
      ),
    );
    final c = container();
    const mine = CompanionCustomization(hairStyle: CompanionHairStyle.locs);
    c.read(companionCustomizationProvider.notifier).set(mine);
    expect(await loaded(c), mine);
  });

  test('storage it cannot read is logged, and she stays as she is', () async {
    await db.saveSettingsItem(companionCustomizationKey, 'not json');
    expect(await loaded(container()), const CompanionCustomization());
    verify(
      () => logger.error(
        LogDomain.settings,
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'companionCustomization',
        message: 'Could not load her customization',
      ),
    ).called(1);
  });

  test('a write that fails is logged, and the change still shows', () async {
    final failing = MockSettingsDb();
    when(() => failing.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => failing.saveSettingsItem(any(), any()),
    ).thenAnswer((_) => Future.error(StateError('disk full')));
    final c = container(failing);
    await loaded(c);
    const custom = CompanionCustomization(hairStyle: CompanionHairStyle.curls);
    c.read(companionCustomizationProvider.notifier).set(custom);
    await pumpEventQueue();
    expect(c.read(companionCustomizationProvider), custom);
    verify(
      () => logger.error(
        LogDomain.settings,
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'companionCustomization',
        message: 'Could not store her customization',
      ),
    ).called(1);
  });
}
