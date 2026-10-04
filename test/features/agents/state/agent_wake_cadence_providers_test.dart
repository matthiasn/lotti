import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/features/agents/state/agent_wake_cadence_providers.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  late MockEntitiesCacheService cache;

  setUp(() async {
    cache = MockEntitiesCacheService();
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  ProviderContainer container({bool withCache = true}) {
    final c = ProviderContainer(
      overrides: withServiceOverrides([
        if (withCache) entitiesCacheServiceProvider.overrideWithValue(cache),
      ]),
    );
    addTearDown(c.dispose);
    return c;
  }

  test("a category's own cadence is what its tasks inherit", () {
    when(() => cache.getCategoryById('cat-1')).thenReturn(
      CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        agentWakeCadence: AgentWakeCadence.live,
      ),
    );

    expect(
      container().read(inheritedTaskWakeCadenceProvider('cat-1')),
      AgentWakeCadence.live,
    );
  });

  test('a category without a cadence passes on the app default', () {
    when(() => cache.getCategoryById('cat-1')).thenReturn(
      CategoryTestUtils.createTestCategory(id: 'cat-1'),
    );
    final c = container();
    c
        .read(aiRuntimeSettingsControllerProvider.notifier)
        .setDefaultWakeCadence(AgentWakeCadence.recordingsOnly);

    expect(
      c.read(inheritedTaskWakeCadenceProvider('cat-1')),
      AgentWakeCadence.recordingsOnly,
    );
  });

  test('no category, or an unknown one, inherits the app default', () {
    when(() => cache.getCategoryById(any())).thenReturn(null);
    final c = container();

    expect(
      c.read(inheritedTaskWakeCadenceProvider(null)),
      AgentWakeCadence.hourly,
    );
    expect(
      c.read(inheritedTaskWakeCadenceProvider('gone')),
      AgentWakeCadence.hourly,
    );
    verifyNever(() => cache.getCategoryById(null));
  });

  test('a world without a category cache inherits the app default', () {
    expect(
      container(withCache: false).read(inheritedTaskWakeCadenceProvider('c')),
      AgentWakeCadence.hourly,
    );
    verifyNever(() => cache.getCategoryById(any()));
  });
}
