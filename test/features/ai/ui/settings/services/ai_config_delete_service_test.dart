import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart'
    show setUpTestGetIt, tearDownTestGetIt;
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
      testWidgets(
        'should successfully delete provider with associated models',
        (WidgetTester tester) async {
          // Arrange
          final cascadeResult = CascadeDeletionResult(
            deletedModels: associatedModels,
            providerName: testProvider.name,
          );

          when(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).thenAnswer((_) async => cascadeResult);

          bool? result;

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                result = await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          // Act - Tap to trigger delete
          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify confirmation dialog appears
          expect(
            find.text('Delete Provider'),
            findsNWidgets(2),
          ); // Button + dialog title
          expect(find.text('This action cannot be undone'), findsOneWidget);
          expect(
            find.text('Associated models will also be deleted'),
            findsOneWidget,
          );

          // Confirm deletion
          await tester.tap(find.text('Delete'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Assert
          expect(result, isTrue);
          verify(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).called(1);

          // Check DS toast appears with cascade description
          expect(find.text('Provider deleted'), findsOneWidget);
          expect(
            find.text('Also removed 2 models: Model 1, Model 2'),
            findsOneWidget,
          );
          expect(find.text('Undo'), findsOneWidget);
        },
      );

      testWidgets('should cancel provider deletion when user cancels', (
        WidgetTester tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Provider'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testProvider,
              );
            },
          ),
        );

        // Act - Tap to trigger delete
        await tester.tap(find.text('Delete Provider'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Cancel deletion
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockRepository.deleteInferenceProviderWithModels(any()),
        );
        expect(find.text('Provider deleted'), findsNothing);
      });
    });

    group('deleteConfig() - Model Deletion', () {
      testWidgets('should successfully delete model', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(
          () => mockRepository.deleteConfig(testModel.id),
        ).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testModel,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testModel.id)).called(1);
        expect(find.text('Model deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });
    });

    group('deleteConfig() - Prompt Deletion', () {
      testWidgets('should successfully delete prompt', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(
          () => mockRepository.deleteConfig(testPrompt.id),
        ).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Prompt'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testPrompt,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Prompt'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testPrompt.id)).called(1);
        expect(find.text('Prompt deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });
    });

    group('deleteConfig() - Profile Deletion', () {
      testWidgets('should successfully delete profile', (
        WidgetTester tester,
      ) async {
        // Arrange
        final testProfile = AiTestDataFactory.createTestProfile(
          id: 'test-profile-id',
          description: 'A test profile for deletion',
        );

        when(
          () => mockRepository.deleteConfig(testProfile.id),
        ).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Profile'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testProfile,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Profile'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testProfile.id)).called(1);
        expect(find.text('Profile deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });

      testWidgets(
        'should display profile confirmation dialog with correct elements',
        (WidgetTester tester) async {
          final testProfile = AiTestDataFactory.createTestProfile(
            id: 'test-profile-id',
            description: 'A test profile for deletion',
          );

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Profile'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProfile,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Profile'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Check dialog structure
          expect(find.text('Delete Profile'), findsNWidgets(2));
          expect(find.text(testProfile.name), findsOneWidget);
          expect(find.byIcon(Icons.tune), findsOneWidget); // Profile icon
          expect(
            find.text(
              'This will permanently delete the inference profile.',
            ),
            findsOneWidget,
          );
        },
      );
    });

    group('Error Handling', () {
      testWidgets('should handle repository errors gracefully', (
        WidgetTester tester,
      ) async {
        // Arrange
        const errorMessage = 'Database connection failed';
        when(
          () => mockRepository.deleteConfig(testModel.id),
        ).thenThrow(Exception(errorMessage));

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testModel,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isFalse);
        expect(
          find.text("Couldn't delete ${testModel.name}"),
          findsOneWidget,
        );
        expect(find.text('Exception: $errorMessage'), findsOneWidget);
      });

      testWidgets('should handle provider cascade deletion errors', (
        WidgetTester tester,
      ) async {
        // Arrange
        const errorMessage = 'Cascade deletion failed';
        when(
          () =>
              mockRepository.deleteInferenceProviderWithModels(testProvider.id),
        ).thenThrow(Exception(errorMessage));

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Provider'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testProvider,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Provider'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        expect(result, isFalse);
        expect(
          find.text("Couldn't delete ${testProvider.name}"),
          findsOneWidget,
        );
      });
    });

    group('Undo Functionality', () {
      testWidgets('should undo model deletion successfully', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(
          () => mockRepository.deleteConfig(testModel.id),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.saveConfig(testModel),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testModel,
              );
            },
          ),
        );

        // Act - Delete the model
        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        // Mirror the DS toast messenger tests: schedule a frame to
        // resolve the tap, then advance the clock past the dialog
        // dismiss + SnackBar slide-in animations. We can't settle
        // because the toast's countdown animation runs the full 5 s.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Undo the deletion
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        verify(() => mockRepository.deleteConfig(testModel.id)).called(1);
        verify(() => mockRepository.saveConfig(testModel)).called(1);
      });

      testWidgets('should undo provider deletion with associated models', (
        WidgetTester tester,
      ) async {
        // Arrange
        final cascadeResult = CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: testProvider.name,
        );

        when(
          () =>
              mockRepository.deleteInferenceProviderWithModels(testProvider.id),
        ).thenAnswer((_) async => cascadeResult);
        when(
          () => mockRepository.saveConfig(testProvider),
        ).thenAnswer((_) async {});
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Provider'),
            onPressed: (context, ref) async {
              await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testProvider,
              );
            },
          ),
        );

        // Act - Delete the provider
        await tester.tap(find.text('Delete Provider'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Undo the deletion
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert
        verify(
          () =>
              mockRepository.deleteInferenceProviderWithModels(testProvider.id),
        ).called(1);
        verify(() => mockRepository.saveConfig(testProvider)).called(1);
        // Verify all associated models are restored
        for (final model in associatedModels) {
          verify(() => mockRepository.saveConfig(model)).called(1);
        }
      });

      testWidgets('should handle undo errors gracefully', (
        WidgetTester tester,
      ) async {
        // Arrange
        when(
          () => mockRepository.deleteConfig(testModel.id),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.saveConfig(testModel),
        ).thenThrow(Exception('Undo failed'));

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testModel,
              );
            },
          ),
        );

        // Act - Delete and then try to undo
        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert - Should not crash or show error to user
        verify(() => mockRepository.saveConfig(testModel)).called(1);
      });
    });

    group('Confirmation Dialog UI', () {
      testWidgets(
        'should display provider confirmation dialog with correct elements',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Check dialog structure
          expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
          expect(
            find.text('Delete Provider'),
            findsNWidgets(2),
          ); // Button + title
          expect(find.text('This action cannot be undone'), findsOneWidget);
          expect(find.text(testProvider.name), findsOneWidget);
          expect(find.text(testProvider.description!), findsOneWidget);
          expect(
            find.text('Associated models will also be deleted'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.hub), findsOneWidget); // Provider icon
          expect(find.text('Cancel'), findsOneWidget);
          expect(
            find.text('Delete'),
            findsAtLeastNWidgets(1),
          ); // At least one Delete button
        },
      );

      testWidgets(
        'should display model confirmation dialog with correct elements',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Model'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testModel,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Model'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Check dialog structure
          expect(find.text('Delete Model'), findsNWidgets(2));
          expect(find.text(testModel.name), findsOneWidget);
          expect(find.byIcon(Icons.smart_toy), findsOneWidget); // Model icon
          expect(
            find.text('This will permanently delete the model configuration.'),
            findsOneWidget,
          );
          // Should NOT show cascade warning for models
          expect(
            find.text('Associated models will also be deleted'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'should display prompt confirmation dialog with correct elements',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Prompt'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testPrompt,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Prompt'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Check dialog structure
          expect(find.text('Delete Prompt'), findsNWidgets(2));
          expect(find.text(testPrompt.name), findsOneWidget);
          expect(find.byIcon(Icons.psychology), findsOneWidget); // Prompt icon
          expect(
            find.text('This will permanently delete the prompt template.'),
            findsOneWidget,
          );
        },
      );
    });

    group('DS Toast UI and Behavior', () {
      testWidgets(
        'should display provider deletion toast with cascade description',
        (WidgetTester tester) async {
          // Arrange
          final cascadeResult = CascadeDeletionResult(
            deletedModels: associatedModels,
            providerName: testProvider.name,
          );

          when(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).thenAnswer((_) async => cascadeResult);

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          // Act
          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Delete'));
          // Don't fully settle — the countdown timer never stops, so
          // pumpAndSettle would time out. A single frame is enough for
          // the toast to render.
          await tester.pump();

          // Assert DS toast content
          expect(find.text('Provider deleted'), findsOneWidget);
          expect(
            find.text('Also removed 2 models: Model 1, Model 2'),
            findsOneWidget,
          );
          expect(find.text('Undo'), findsOneWidget);
          // Success/warning tone glyph from the DS toast spec.
          expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
        },
      );

      testWidgets(
        'should list every model name in cascade description, even when many',
        (WidgetTester tester) async {
          // Arrange — many associated models. The DS toast description
          // is a single string; visual ellipsis is purely cosmetic, so
          // the full joined list still matches `find.text`.
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

          when(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).thenAnswer((_) async => cascadeResult);

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          // Act
          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Delete'));
          await tester.pump();

          // Assert: description carries the joined list of all 6 names.
          expect(
            find.text(
              'Also removed 6 models: Model 0, Model 1, Model 2, Model 3, '
              'Model 4, Model 5',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('should display error toast with error tone', (
        WidgetTester tester,
      ) async {
        // Arrange
        const errorMessage = 'Network error occurred';
        when(
          () => mockRepository.deleteConfig(testModel.id),
        ).thenThrow(Exception(errorMessage));

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testModel,
              );
            },
          ),
        );

        // Act
        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        await tester.pump();

        // Assert error DS toast: error-tone glyph + localized title +
        // error detail in the description.
        expect(find.byIcon(Icons.error_rounded), findsOneWidget);
        expect(
          find.text("Couldn't delete ${testModel.name}"),
          findsOneWidget,
        );
        expect(find.text('Exception: $errorMessage'), findsOneWidget);
      });
    });

    group('Edge Cases and Context Safety', () {
      testWidgets('should handle config without description', (
        WidgetTester tester,
      ) async {
        final configWithoutDescription = AiTestDataFactory.createTestModel(
          description: null,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Model'),
            onPressed: (context, ref) async {
              await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: configWithoutDescription,
              );
            },
          ),
        );

        await tester.tap(find.text('Delete Model'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should not crash and should show dialog
        expect(find.text('Delete Model'), findsNWidgets(2));
        expect(find.text(configWithoutDescription.name), findsOneWidget);
      });

      testWidgets(
        'should handle empty associated models for provider deletion',
        (WidgetTester tester) async {
          // Arrange
          final cascadeResult = CascadeDeletionResult(
            deletedModels: [], // No associated models
            providerName: testProvider.name,
          );

          when(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).thenAnswer((_) async => cascadeResult);

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          // Act
          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Delete'));
          await tester.pump();

          // Assert - Title fires, but no cascade description because
          // no models were associated with the provider.
          expect(find.text('Provider deleted'), findsOneWidget);
          expect(find.textContaining('Also removed'), findsNothing);
        },
      );
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

    group('deleteConfig() - Skill Deletion', () {
      late AiConfigSkill testSkill;

      setUp(() {
        testSkill =
            AiConfig.skill(
                  id: 'test-skill-id',
                  name: 'Test Skill',
                  description: 'A test skill for deletion',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.imageAnalysis,
                  requiredInputModalities: const [Modality.image],
                  systemInstructions: 'Analyze the image.',
                  userInstructions: 'Please describe this image.',
                )
                as AiConfigSkill;
      });

      testWidgets('should successfully delete skill and show skill toast', (
        WidgetTester tester,
      ) async {
        when(
          () => mockRepository.deleteConfig(testSkill.id),
        ).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Skill'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testSkill,
              );
            },
          ),
        );

        await tester.tap(find.text('Delete Skill'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm the deletion in the dialog
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(result, isTrue);
        verify(() => mockRepository.deleteConfig(testSkill.id)).called(1);
        // The DS toast shows the skill-specific title and an undo action.
        expect(find.text('Skill deleted'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      });

      testWidgets(
        'should display skill confirmation dialog with correct elements',
        (
          WidgetTester tester,
        ) async {
          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Skill'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testSkill,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Skill'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Dialog title, warning text, and icon must all reflect the Skill type.
          expect(find.text('Delete Skill'), findsNWidgets(2));
          expect(find.text(testSkill.name), findsOneWidget);
          expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
          expect(
            find.text('This will permanently delete the skill.'),
            findsOneWidget,
          );
          // Skills have no cascade warning.
          expect(
            find.text('Associated models will also be deleted'),
            findsNothing,
          );
        },
      );

      testWidgets('should cancel skill deletion when user cancels', (
        WidgetTester tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Delete Skill'),
            onPressed: (context, ref) async {
              result = await deleteService.deleteConfig(
                context: context,
                ref: ref,
                config: testSkill,
              );
            },
          ),
        );

        await tester.tap(find.text('Delete Skill'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(result, isFalse);
        verifyNever(() => mockRepository.deleteConfig(any()));
      });
    });

    // Tests for the DomainLogger logging paths inside undo error handlers.
    // These paths execute when getIt<DomainLogger>() resolves (i.e. getIt is
    // set up) and the saveConfig call throws during undo.
    group('Undo Error Logging (with DomainLogger in GetIt)', () {
      setUp(() async {
        await setUpTestGetIt();
      });

      tearDown(() async {
        await tearDownTestGetIt();
      });

      testWidgets(
        'should log via DomainLogger when config undo fails with logger available',
        (WidgetTester tester) async {
          when(
            () => mockRepository.deleteConfig(testModel.id),
          ).thenAnswer((_) async {});
          when(
            () => mockRepository.saveConfig(testModel),
          ).thenThrow(Exception('Undo failed – logger path'));

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Model'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testModel,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Model'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Delete'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          await tester.tap(find.text('Undo'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // saveConfig was called (and threw); the service must not re-throw.
          verify(() => mockRepository.saveConfig(testModel)).called(1);
          // The UI stays stable — no error shown to the user for undo failures.
          expect(find.text("Couldn't delete ${testModel.name}"), findsNothing);
        },
      );

      testWidgets(
        'should log via DomainLogger when provider undo fails with logger available',
        (WidgetTester tester) async {
          final cascadeResult = CascadeDeletionResult(
            deletedModels: associatedModels,
            providerName: testProvider.name,
          );

          when(
            () => mockRepository.deleteInferenceProviderWithModels(
              testProvider.id,
            ),
          ).thenAnswer((_) async => cascadeResult);
          // saveConfig throws on any call (provider restore + model restores).
          when(
            () => mockRepository.saveConfig(any()),
          ).thenThrow(Exception('Provider undo failed – logger path'));

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Delete Provider'),
              onPressed: (context, ref) async {
                await deleteService.deleteConfig(
                  context: context,
                  ref: ref,
                  config: testProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Delete Provider'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Delete'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          await tester.tap(find.text('Undo'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // saveConfig was called (and threw); service must not propagate.
          verify(() => mockRepository.saveConfig(any())).called(1);
          // The UI stays stable — no error shown to the user for undo failures.
          expect(
            find.text("Couldn't delete ${testProvider.name}"),
            findsNothing,
          );
        },
      );
    });
  });
}
