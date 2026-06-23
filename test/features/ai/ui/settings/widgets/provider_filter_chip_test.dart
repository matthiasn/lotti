import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chip.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../../widget_test_utils.dart';

AiConfigInferenceProvider _provider({
  String name = 'Test Provider',
  InferenceProviderType type = InferenceProviderType.anthropic,
}) => AiConfigInferenceProvider(
  id: 'provider1',
  name: name,
  baseUrl: 'https://example.com',
  apiKey: 'test-key',
  createdAt: DateTime(2024, 3, 15),
  inferenceProviderType: type,
);

void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required AiConfig? config,
    bool isSelected = false,
    VoidCallback? onTap,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiConfigByIdProvider('provider1').overrideWith((ref) async => config),
        ],
        child: MaterialApp(
          theme: resolveTestTheme(theme),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProviderFilterChip(
              providerId: 'provider1',
              isSelected: isSelected,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DesignSystemChip chipOf(WidgetTester tester) =>
      tester.widget<DesignSystemChip>(find.byType(DesignSystemChip));

  Color avatarColorOf(WidgetTester tester) {
    final avatar = chipOf(tester).avatar! as DecoratedBox;
    final gradient =
        (avatar.decoration as BoxDecoration).gradient! as LinearGradient;
    return gradient.colors.first;
  }

  group('ProviderFilterChip', () {
    testWidgets('renders the provider name in a DesignSystemChip', (
      tester,
    ) async {
      await pumpChip(tester, config: _provider());

      expect(find.byType(DesignSystemChip), findsOneWidget);
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('reflects the selected / unselected state on the chip', (
      tester,
    ) async {
      await pumpChip(tester, config: _provider(), isSelected: true);
      expect(chipOf(tester).selected, isTrue);

      await pumpChip(tester, config: _provider());
      expect(chipOf(tester).selected, isFalse);
    });

    testWidgets('tapping invokes onTap, including rapid taps', (tester) async {
      var taps = 0;
      await pumpChip(tester, config: _provider(), onTap: () => taps++);

      await tester.tap(find.byType(DesignSystemChip));
      await tester.pump();
      await tester.tap(find.byType(DesignSystemChip));
      await tester.pump();
      await tester.tap(find.byType(DesignSystemChip));
      await tester.pump();

      expect(taps, 3);
    });

    testWidgets('carries the provider colour on its gradient avatar dot', (
      tester,
    ) async {
      await pumpChip(
        tester,
        config: _provider(type: InferenceProviderType.openAi),
        theme: ThemeData.light(),
      );

      expect(
        avatarColorOf(tester),
        ProviderChipConstants.getProviderColor(
          InferenceProviderType.openAi,
          isDark: false,
        ),
      );
    });

    testWidgets('renders nothing when the provider is missing', (tester) async {
      await pumpChip(tester, config: null);
      expect(find.byType(DesignSystemChip), findsNothing);
    });
  });

  group('ProviderFilterChip data state', () {
    test('Null provider returns null from async state', () async {
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('provider1').overrideWith((ref) async => null),
        ],
      );

      final result = await container.read(
        aiConfigByIdProvider('provider1').future,
      );
      expect(result, isNull);

      container.dispose();
    });

    test('Error state propagates error from provider', () async {
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider('provider1').overrideWith(
            (ref) => Future.error(Exception('Failed to load')),
          ),
        ],
      );

      expect(
        () => container.read(aiConfigByIdProvider('provider1').future),
        throwsA(isA<Exception>()),
      );

      container.dispose();
    });

    test('Valid provider returns correct data', () async {
      final provider = _provider();
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider(
            'provider1',
          ).overrideWith((ref) async => provider),
        ],
      );

      final result = await container.read(
        aiConfigByIdProvider('provider1').future,
      );
      expect(result, equals(provider));

      container.dispose();
    });
  });
}
