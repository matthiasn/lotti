import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils.dart';

void main() {
  group('AiConfigDeleteService Comprehensive Tests', () {
    late AiConfigDeleteService deleteService;
    late MockAiConfigRepository mockRepository;
    late AiConfigInferenceProvider testProvider;
    late AiConfigModel testModel;
    late AiConfigPrompt testPrompt;
    late List<AiConfigModel> associatedModels;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      deleteService = const AiConfigDeleteService();
      mockRepository = MockAiConfigRepository();

      testProvider = AiTestDataFactory.createTestProvider(
        id: 'test-provider-id',
        description: 'A test provider for deletion',
      );

      testModel = AiTestDataFactory.createTestModel(
        id: 'test-model-id',
        description: 'A test model for deletion',
        inferenceProviderId: testProvider.id,
      );

      testPrompt = AiTestDataFactory.createTestPrompt(
        id: 'test-prompt-id',
        description: 'A test prompt for deletion',
      );

      associatedModels = [
        AiTestDataFactory.createTestModel(
          id: 'model-1',
          name: 'Model 1',
          inferenceProviderId: testProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'model-2',
          name: 'Model 2',
          inferenceProviderId: testProvider.id,
        ),
      ];
    });

    Widget createTestWidget({
      required Widget child,
      required Future<void> Function(BuildContext, WidgetRef) onPressed,
    }) {
      return AiTestWidgets.createTestWidget(
        repository: mockRepository,
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => onPressed(context, ref),
            child: child,
          ),
        ),
      );
    }

    group('deleteConfig() - Provider Deletion', () {
      testWidgets('should successfully delete provider with associated models',
          (WidgetTester tester) async {
        // Arrange
        final cascadeResult = CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: testProvider.name,
        );

        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenAnswer((_) async => cascadeResult);

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act - Tap to trigger delete
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();

        // Verify confirmation dialog appears
        expect(find.text('Delete Provider'),
            findsNWidgets(2)); // Button + dialog title
        expect(find.text('This action cannot be undone'), findsOneWidget);
        expect(find.text('Associated models will also be deleted'),
            findsOneWidget);

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository
            .deleteInferenceProviderWithModels(testProvider.id)).called(1);

        // Check snackbar appears
        expect(find.text('Provider deleted successfully'), findsOneWidget);
        expect(find.text('2 associated models deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });

      testWidgets('should cancel provider deletion when user cancels',
          (WidgetTester tester) async {
        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act - Tap to trigger delete
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();

        // Cancel deletion
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockRepository.deleteInferenceProviderWithModels(any()));
        expect(find.text('Provider deleted successfully'), findsNothing);
      });
    });

    group('deleteConfig() - Model Deletion', () {
      testWidgets('should successfully delete model',
          (WidgetTester tester) async {
        // Arrange
        when(() => mockRepository.deleteConfig(testModel.id))
            .thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testModel.id)).called(1);
        expect(find.text('Model deleted successfully'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });
    });

    group('deleteConfig() - Prompt Deletion', () {
      testWidgets('should successfully delete prompt',
          (WidgetTester tester) async {
        // Arrange
        when(() => mockRepository.deleteConfig(testPrompt.id))
            .thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Prompt'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testPrompt,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Prompt'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testPrompt.id)).called(1);
        expect(find.text('Prompt deleted successfully'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle repository errors gracefully',
          (WidgetTester tester) async {
        // Arrange
        const errorMessage = 'Database connection failed';
        when(() => mockRepository.deleteConfig(testModel.id))
            .thenThrow(Exception(errorMessage));

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isFalse);
        expect(find.text('Failed to delete ${testModel.name}'), findsOneWidget);
        expect(find.text('Exception: $errorMessage'), findsOneWidget);
      });

      testWidgets('should handle provider cascade deletion errors',
          (WidgetTester tester) async {
        // Arrange
        const errorMessage = 'Cascade deletion failed';
        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenThrow(Exception(errorMessage));

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            result = await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert
        expect(result, isFalse);
        expect(
            find.text('Failed to delete ${testProvider.name}'), findsOneWidget);
      });
    });

    group('Undo Functionality', () {
      testWidgets('should undo model deletion successfully',
          (WidgetTester tester) async {
        // Arrange
        when(() => mockRepository.deleteConfig(testModel.id))
            .thenAnswer((_) async {});
        when(() => mockRepository.saveConfig(testModel))
            .thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        // Act - Delete the model
        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Undo the deletion
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Assert
        verify(() => mockRepository.deleteConfig(testModel.id)).called(1);
        verify(() => mockRepository.saveConfig(testModel)).called(1);
      });

      testWidgets('should undo provider deletion with associated models',
          (WidgetTester tester) async {
        // Arrange
        final cascadeResult = CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: testProvider.name,
        );

        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenAnswer((_) async => cascadeResult);
        when(() => mockRepository.saveConfig(testProvider))
            .thenAnswer((_) async {});
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act - Delete the provider
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Undo the deletion
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Assert
        verify(() => mockRepository
            .deleteInferenceProviderWithModels(testProvider.id)).called(1);
        verify(() => mockRepository.saveConfig(testProvider)).called(1);
        // Verify all associated models are restored
        for (final model in associatedModels) {
          verify(() => mockRepository.saveConfig(model)).called(1);
        }
      });

      testWidgets('should handle undo errors gracefully',
          (WidgetTester tester) async {
        // Arrange
        when(() => mockRepository.deleteConfig(testModel.id))
            .thenAnswer((_) async {});
        when(() => mockRepository.saveConfig(testModel))
            .thenThrow(Exception('Undo failed'));

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        // Act - Delete and then try to undo
        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // Assert - Should not crash or show error to user
        verify(() => mockRepository.saveConfig(testModel)).called(1);
      });
    });

    group('Confirmation Dialog UI', () {
      testWidgets(
          'should display provider confirmation dialog with correct elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();

        // Check dialog structure
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(
            find.text('Delete Provider'), findsNWidgets(2)); // Button + title
        expect(find.text('This action cannot be undone'), findsOneWidget);
        expect(find.text(testProvider.name), findsOneWidget);
        expect(find.text(testProvider.description!), findsOneWidget);
        expect(find.text('Associated models will also be deleted'),
            findsOneWidget);
        expect(find.byIcon(Icons.hub), findsOneWidget); // Provider icon
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'),
            findsAtLeastNWidgets(1)); // At least one Delete button
      });

      testWidgets(
          'should display model confirmation dialog with correct elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();

        // Check dialog structure
        expect(find.text('Delete Model'), findsNWidgets(2));
        expect(find.text(testModel.name), findsOneWidget);
        expect(find.byIcon(Icons.smart_toy), findsOneWidget); // Model icon
        expect(
            find.text('This will permanently delete the model configuration.'),
            findsOneWidget);
        // Should NOT show cascade warning for models
        expect(
            find.text('Associated models will also be deleted'), findsNothing);
      });

      testWidgets(
          'should display prompt confirmation dialog with correct elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Prompt'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testPrompt,
            );
          },
        ));

        await tester.tap(find.text('Delete Prompt'));
        await tester.pumpAndSettle();

        // Check dialog structure
        expect(find.text('Delete Prompt'), findsNWidgets(2));
        expect(find.text(testPrompt.name), findsOneWidget);
        expect(find.byIcon(Icons.psychology), findsOneWidget); // Prompt icon
        expect(find.text('This will permanently delete the prompt template.'),
            findsOneWidget);
      });
    });

    group('Snackbar UI and Behavior', () {
      testWidgets('should display provider deletion snackbar with cascade info',
          (WidgetTester tester) async {
        // Arrange
        final cascadeResult = CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: testProvider.name,
        );

        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenAnswer((_) async => cascadeResult);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert snackbar content
        expect(find.byIcon(Icons.delete_forever_outlined), findsOneWidget);
        expect(find.text('Provider deleted successfully'), findsOneWidget);
        expect(find.text('2 associated models deleted'), findsOneWidget);
        expect(find.text('Model 1'), findsOneWidget);
        expect(find.text('Model 2'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });

      testWidgets('should handle many associated models in snackbar',
          (WidgetTester tester) async {
        // Arrange - Create many associated models
        final manyModels = List.generate(
          6,
          (index) => AiTestDataFactory.createTestModel(
            id: 'model-$index',
            name: 'Model $index',
            inferenceProviderId: testProvider.id,
          ),
        );

        final cascadeResult = CascadeDeletionResult(
          deletedModels: manyModels,
          providerName: testProvider.name,
        );

        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenAnswer((_) async => cascadeResult);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert - Should show truncated list
        expect(find.text('6 associated models deleted'), findsOneWidget);
        expect(find.text('Model 0, Model 1 and 4 more'), findsOneWidget);
      });

      testWidgets('should display error snackbar with correct styling',
          (WidgetTester tester) async {
        // Arrange
        const errorMessage = 'Network error occurred';
        when(() => mockRepository.deleteConfig(testModel.id))
            .thenThrow(Exception(errorMessage));

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testModel,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert error snackbar
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Failed to delete ${testModel.name}'), findsOneWidget);
        expect(find.text('Exception: $errorMessage'), findsOneWidget);
      });
    });

    group('Edge Cases and Context Safety', () {
      testWidgets('should handle config without description',
          (WidgetTester tester) async {
        final configWithoutDescription = AiTestDataFactory.createTestModel(
          description: null,
        );

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Model'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: configWithoutDescription,
            );
          },
        ));

        await tester.tap(find.text('Delete Model'));
        await tester.pumpAndSettle();

        // Should not crash and should show dialog
        expect(find.text('Delete Model'), findsNWidgets(2));
        expect(find.text(configWithoutDescription.name), findsOneWidget);
      });

      testWidgets('should handle empty associated models for provider deletion',
          (WidgetTester tester) async {
        // Arrange
        final cascadeResult = CascadeDeletionResult(
          deletedModels: [], // No associated models
          providerName: testProvider.name,
        );

        when(() => mockRepository.deleteInferenceProviderWithModels(
            testProvider.id)).thenAnswer((_) async => cascadeResult);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Delete Provider'),
          onPressed: (context, ref) async {
            await deleteService.deleteConfig(
              context: context,
              ref: ref,
              config: testProvider,
            );
          },
        ));

        // Act
        await tester.tap(find.text('Delete Provider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Assert - Should not show cascade information
        expect(find.text('Provider deleted successfully'), findsOneWidget);
        expect(find.text('associated models deleted'), findsNothing);
      });
    });

    group('Service Construction and Identity', () {
      test('should be const constructible', () {
        const service1 = AiConfigDeleteService();
        const service2 = AiConfigDeleteService();
        expect(service1, isA<AiConfigDeleteService>());
        expect(service2, isA<AiConfigDeleteService>());
      });

      test('should maintain consistent behavior across instances', () {
        const service1 = AiConfigDeleteService();
        const service2 = AiConfigDeleteService();
        expect(identical(service1, service2), isTrue);
      });
    });
  });
}
