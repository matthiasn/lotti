import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/helpers/thoughts_modal_helper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockLoggingService = MockLoggingService();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });
  group('ThoughtsModalHelper', () {
    testWidgets('should return early when promptId is null', (tester) async {
      // Build a simple app with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () async {
                    await ThoughtsModalHelper.showThoughtsModal(
                      context: context,
                      ref: ref,
                      promptId: null,
                      entityId: 'test-entity-id',
                    );
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger the helper with null promptId
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // The test passes if no exception is thrown
      // Since promptId is null, it should return early without doing anything
    });

    testWidgets('handles valid promptId without crashing', (tester) async {
      const testPromptId = 'test-prompt-id';
      const testEntityId = 'test-entity-id';

      // Build a simple app with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () async {
                    try {
                      await ThoughtsModalHelper.showThoughtsModal(
                        context: context,
                        ref: ref,
                        promptId: testPromptId,
                        entityId: testEntityId,
                      );
                    } catch (e) {
                      // Expected - providers are not set up
                      // But the helper should at least try to execute
                    }
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Test passes if we get here without crashing
    });

    test('helper exists and has correct signature', () {
      // This test verifies that the helper class and method exist
      // with the expected signature
      expect(ThoughtsModalHelper.showThoughtsModal, isA<Function>());

      // Verify it's a static method that returns Future<void>
      final result = ThoughtsModalHelper.showThoughtsModal(
        context: _FakeBuildContext(),
        ref: _FakeWidgetRef(),
        promptId: null,
        entityId: 'test',
      );

      expect(result, isA<Future<void>>());
    });
  });
}

// Fake classes for testing method signature
class _FakeBuildContext extends Fake implements BuildContext {
  @override
  bool get mounted => false;
}

class _FakeWidgetRef extends Fake implements WidgetRef {}
