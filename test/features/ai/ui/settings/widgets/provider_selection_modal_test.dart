import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_selection_modal.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

/// Serves whatever [_stream] does, so a test can hold the provider list in
/// its loading or failed state.
class _StreamConfigController extends AiConfigByTypeController {
  _StreamConfigController(this._stream);

  final Stream<List<AiConfig>> _stream;

  @override
  Stream<List<AiConfig>> build() => _stream;
}

void main() {
  final first = AiTestDataFactory.createTestProvider(
    id: 'provider-1',
    name: 'First Provider',
    description: 'Hosts the fast models',
  );
  final second = AiTestDataFactory.createTestProvider(
    id: 'provider-2',
    name: 'Second Provider',
    description: null,
  );

  Override providersOverride(AiConfigByTypeController Function() create) =>
      aiConfigByTypeControllerProvider(
        AiConfigType.inferenceProvider,
      ).overrideWith(create);

  /// Pumps a page with an "Open picker" button that pushes the modal as a
  /// route, the way it is shown in the app, and opens it. Returns the ids the
  /// modal reports as selected.
  Future<List<String>> openPicker(
    WidgetTester tester, {
    required Override providers,
    String selectedProviderId = '',
  }) async {
    final selections = <String>[];
    final host = makeTestableWidgetWithContainer(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: ProviderSelectionModal(
                    onProviderSelected: selections.add,
                    selectedProviderId: selectedProviderId,
                  ),
                ),
              ),
            ),
            child: const Text('Open picker'),
          ),
        ),
      ),
      overrides: [providers],
      // Riverpod reports a failed provider as loading while it retries, so
      // the error state is only reachable with retries off.
      retry: (_, _) => null,
    );
    addTearDown(host.container.dispose);
    await tester.pumpWidget(host.widget);
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    return selections;
  }

  Override listing(List<AiConfig> configs) =>
      providersOverride(() => MockAiConfigByTypeController(configs));

  Finder cardOf(String providerName) => find.ancestor(
    of: find.text(providerName),
    matching: find.byType(InkWell),
  );

  group('ProviderSelectionModal', () {
    testWidgets('lists each provider by name and description, and skips '
        'configs that are not providers', (tester) async {
      await openPicker(
        tester,
        providers: listing([
          first,
          second,
          AiTestDataFactory.createTestModel(
            id: 'model-stray',
            name: 'Stray Model',
          ),
        ]),
      );

      expect(find.text('First Provider'), findsOneWidget);
      expect(find.text('Hosts the fast models'), findsOneWidget);
      expect(find.text('Second Provider'), findsOneWidget);
      expect(find.text('Stray Model'), findsNothing);
      expect(find.byIcon(LottiIcons.cloud), findsNWidgets(2));
    });

    testWidgets('only the selected provider carries the check mark', (
      tester,
    ) async {
      await openPicker(
        tester,
        providers: listing([first, second]),
        selectedProviderId: 'provider-2',
      );

      Finder checkIn(String name) => find.descendant(
        of: cardOf(name),
        matching: find.byIcon(LottiIcons.confirm),
      );
      expect(checkIn('Second Provider'), findsOneWidget);
      expect(checkIn('First Provider'), findsNothing);
    });

    testWidgets('tapping another provider reports it, then closes after the '
        'selection has shown for a moment', (tester) async {
      final selections = await openPicker(
        tester,
        providers: listing([first, second]),
        selectedProviderId: 'provider-1',
      );

      await tester.tap(cardOf('Second Provider'));
      await tester.pump();

      expect(selections, ['provider-2']);
      expect(find.byType(ProviderSelectionModal), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderSelectionModal), findsNothing);
      expect(selections, ['provider-2']);
    });

    testWidgets('tapping the already-selected provider reports it and '
        'closes', (tester) async {
      final selections = await openPicker(
        tester,
        providers: listing([first, second]),
        selectedProviderId: 'provider-1',
      );

      await tester.tap(cardOf('First Provider'));
      await tester.pumpAndSettle();

      expect(selections, ['provider-1']);
      expect(find.byType(ProviderSelectionModal), findsNothing);
      expect(find.text('Open picker'), findsOneWidget);
    });

    testWidgets('says so when there are no providers yet', (tester) async {
      await openPicker(tester, providers: listing(const []));

      expect(find.text('No providers found'), findsOneWidget);
      expect(find.text('Create an inference provider first'), findsOneWidget);
      expect(find.byIcon(LottiIcons.cloudOff), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows a spinner, not the empty state, while the providers '
        'load', (tester) async {
      final pending = StreamController<List<AiConfig>>();
      addTearDown(pending.close);
      final host = makeTestableWidgetWithContainer(
        Scaffold(
          body: ProviderSelectionModal(
            onProviderSelected: (_) {},
            selectedProviderId: '',
          ),
        ),
        overrides: [
          providersOverride(() => _StreamConfigController(pending.stream)),
        ],
      );
      addTearDown(host.container.dispose);
      await tester.pumpWidget(host.widget);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No providers found'), findsNothing);

      pending.add([first]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('First Provider'), findsOneWidget);
    });

    testWidgets('shows the error state when the providers cannot be read', (
      tester,
    ) async {
      await openPicker(
        tester,
        providers: providersOverride(
          () => _StreamConfigController(Stream.error(StateError('db gone'))),
        ),
      );

      expect(find.text('Error loading providers'), findsOneWidget);
      expect(find.byIcon(LottiIcons.error), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No providers found'), findsNothing);
    });
  });
}
