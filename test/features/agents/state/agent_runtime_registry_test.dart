import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';

import '../test_data/entity_factories.dart';

/// Records which hooks ran, so a test can assert on ordering and containment
/// rather than only on a return value.
class _RecordingMaintenance implements AgentRuntimeMaintenance {
  _RecordingMaintenance({this.beforeScanError});

  /// Thrown by [beforeWakeScan] when set, to exercise the runtime's handling.
  final Error? beforeScanError;
  int beforeScanCalls = 0;
  int restoreCalls = 0;

  @override
  Future<void> beforeWakeScan() async {
    beforeScanCalls++;
    if (beforeScanError != null) throw beforeScanError!;
  }

  @override
  Future<void> restoreSubscriptions() async {
    restoreCalls++;
  }
}

void main() {
  group('agentWakeRunnersProvider', () {
    test('defaults to empty so no kind is registered without wiring', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(agentWakeRunnersProvider), isEmpty);
    });

    test('an override registers a runner reachable by kind', () async {
      final container = ProviderContainer(
        overrides: [
          agentWakeRunnersProvider.overrideWithValue({
            'my_kind':
                ({
                  required agentIdentity,
                  required runKey,
                  required triggerTokens,
                  required threadId,
                }) async => const WakeResult(success: true),
          }),
        ],
      );
      addTearDown(container.dispose);

      final runners = container.read(agentWakeRunnersProvider);
      expect(runners.keys, ['my_kind']);

      final result = await runners['my_kind']!(
        agentIdentity: makeTestIdentity(agentId: 'a1'),
        runKey: 'run-1',
        triggerTokens: const {'t'},
        threadId: 'thread-1',
      );
      expect(result.success, isTrue);
    });

    test('an unregistered kind resolves to null rather than throwing', () {
      // The wake executor treats a null lookup as "fall through to the default
      // workflow", so absence must be a lookup miss, not an error.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(agentWakeRunnersProvider)['absent'], isNull);
    });
  });

  group('agentRuntimeMaintenanceProvider', () {
    test('defaults to empty so the runtime runs no contributed repairs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(agentRuntimeMaintenanceProvider), isEmpty);
    });

    test(
      'an override exposes contributors whose hooks are invocable',
      () async {
        final maintenance = _RecordingMaintenance();
        final container = ProviderContainer(
          overrides: [
            agentRuntimeMaintenanceProvider.overrideWithValue([maintenance]),
          ],
        );
        addTearDown(container.dispose);

        final contributors = container.read(agentRuntimeMaintenanceProvider);
        expect(contributors, hasLength(1));

        await contributors.single.beforeWakeScan();
        await contributors.single.restoreSubscriptions();

        expect(maintenance.beforeScanCalls, 1);
        expect(maintenance.restoreCalls, 1);
      },
    );

    test('a contributor may surface a failure to its caller', () async {
      // The contract is that the runtime, not the contract, decides what to do
      // with an escaping failure — so the hook must be allowed to throw.
      final maintenance = _RecordingMaintenance(
        beforeScanError: StateError('boom'),
      );

      await expectLater(
        maintenance.beforeWakeScan,
        throwsA(isA<StateError>()),
      );
      expect(maintenance.beforeScanCalls, 1);
    });
  });

  group('dailyOsSetupSheetLauncherProvider', () {
    test('defaults to null so the entry point stays disabled when unwired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(dailyOsSetupSheetLauncherProvider), isNull);
    });

    test('an override supplies a launcher that receives the context', () {
      BuildContext? seen;
      final container = ProviderContainer(
        overrides: [
          dailyOsSetupSheetLauncherProvider.overrideWithValue(
            (context) => seen = context,
          ),
        ],
      );
      addTearDown(container.dispose);

      final launcher = container.read(dailyOsSetupSheetLauncherProvider);
      expect(launcher, isNotNull);

      final element = _StubElement();
      launcher!(element);
      expect(seen, same(element));
    });
  });
}

/// Minimal BuildContext stand-in: the launcher only forwards it.
class _StubElement extends StatelessElement {
  _StubElement() : super(const _StubWidget());
}

class _StubWidget extends StatelessWidget {
  const _StubWidget();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
