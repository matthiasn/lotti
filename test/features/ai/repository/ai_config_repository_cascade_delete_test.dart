import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigDb extends Mock implements AiConfigDb {}

class MockOutboxService extends Mock implements OutboxService {}

class FakeAiConfig extends Fake implements AiConfig {}

class FakeSyncMessage extends Fake implements SyncMessage {}

void main() {
  late MockAiConfigDb mockDb;
  late MockOutboxService mockOutboxService;
  late AiConfigRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfig());
    registerFallbackValue(FakeSyncMessage());
  });

  setUp(() {
    mockDb = MockAiConfigDb();
    mockOutboxService = MockOutboxService();
    repository = AiConfigRepository(mockDb);

    // Register mock services
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
    getIt.registerSingleton<OutboxService>(mockOutboxService);

    // Setup default mocks
    when(() => mockOutboxService.enqueueMessage(any()))
        .thenAnswer((_) async => {});

    // Setup default transaction mock to execute the callback
    when(() => mockDb.transaction<int>(any())).thenAnswer((invocation) async {
      final callback =
          invocation.positionalArguments[0] as Future<int> Function();
      return callback();
    });
  });

  tearDown(() {
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
  });

  group('deleteInferenceProviderWithModels', () {
    test('should delete provider and all associated models', () async {
      // Arrange
      const providerId = 'provider-123';

      final model1 = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      final model2 = AiConfigModel(
        id: 'model-2',
        name: 'Model 2',
        providerModelId: 'provider-model-2',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: true,
      );

      // Model from different provider
      final otherModel = AiConfigModel(
        id: 'model-3',
        name: 'Model 3',
        providerModelId: 'provider-model-3',
        inferenceProviderId: 'other-provider',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => [
                AiConfigDbEntity(
                  id: model1.id,
                  type: 'AiConfigModel',
                  name: model1.name,
                  serialized: jsonEncode(model1.toJson()),
                  createdAt: model1.createdAt,
                ),
                AiConfigDbEntity(
                  id: model2.id,
                  type: 'AiConfigModel',
                  name: model2.name,
                  serialized: jsonEncode(model2.toJson()),
                  createdAt: model2.createdAt,
                ),
                AiConfigDbEntity(
                  id: otherModel.id,
                  type: 'AiConfigModel',
                  name: otherModel.name,
                  serialized: jsonEncode(otherModel.toJson()),
                  createdAt: otherModel.createdAt,
                ),
              ]);

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final deletedCount =
          await repository.deleteInferenceProviderWithModels(providerId);

      // Assert
      expect(deletedCount, equals(2));

      // Verify models were deleted
      verify(() => mockDb.deleteConfig('model-1')).called(1);
      verify(() => mockDb.deleteConfig('model-2')).called(1);

      // Verify provider was deleted
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify other model was not deleted
      verifyNever(() => mockDb.deleteConfig('model-3'));

      // Verify sync messages were sent
      verify(() => mockOutboxService.enqueueMessage(any())).called(3);
    });

    test('should handle provider with no models', () async {
      // Arrange
      const providerId = 'provider-with-no-models';

      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => []);

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final deletedCount =
          await repository.deleteInferenceProviderWithModels(providerId);

      // Assert
      expect(deletedCount, equals(0));

      // Verify only provider was deleted
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify sync message was sent for provider deletion
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('should not send sync messages when fromSync is true', () async {
      // Arrange
      const providerId = 'provider-sync';
      final model = AiConfigModel(
        id: 'model-sync',
        name: 'Model Sync',
        providerModelId: 'provider-model-sync',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => [
                AiConfigDbEntity(
                  id: model.id,
                  type: 'AiConfigModel',
                  name: model.name,
                  serialized: jsonEncode(model.toJson()),
                  createdAt: model.createdAt,
                ),
              ]);

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final deletedCount = await repository.deleteInferenceProviderWithModels(
        providerId,
        fromSync: true,
      );

      // Assert
      expect(deletedCount, equals(1));

      // Verify deletions happened
      verify(() => mockDb.deleteConfig('model-sync')).called(1);
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify no sync messages were sent
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('should handle database errors gracefully', () async {
      // Arrange
      const providerId = 'provider-error';

      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Database error'),
        )),
      );
    });

    test('should delete multiple models in correct order', () async {
      // Arrange
      const providerId = 'provider-multi';
      final models = List.generate(
        5,
        (i) => AiConfigModel(
          id: 'model-$i',
          name: 'Model $i',
          providerModelId: 'provider-model-$i',
          inferenceProviderId: providerId,
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );

      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => models
            .map((m) => AiConfigDbEntity(
                  id: m.id,
                  type: 'AiConfigModel',
                  name: m.name,
                  serialized: jsonEncode(m.toJson()),
                  createdAt: m.createdAt,
                ))
            .toList(),
      );

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final deletedCount =
          await repository.deleteInferenceProviderWithModels(providerId);

      // Assert
      expect(deletedCount, equals(5));

      // Verify all models were deleted
      for (var i = 0; i < 5; i++) {
        verify(() => mockDb.deleteConfig('model-$i')).called(1);
      }

      // Verify provider was deleted after models
      verify(() => mockDb.deleteConfig(providerId)).called(1);
    });

    test('should rollback transaction when model deletion fails', () async {
      // Arrange
      const providerId = 'provider-rollback';

      final model1 = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      final model2 = AiConfigModel(
        id: 'model-2',
        name: 'Model 2',
        providerModelId: 'provider-model-2',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => [
                AiConfigDbEntity(
                  id: model1.id,
                  type: 'AiConfigModel',
                  name: model1.name,
                  serialized: jsonEncode(model1.toJson()),
                  createdAt: model1.createdAt,
                ),
                AiConfigDbEntity(
                  id: model2.id,
                  type: 'AiConfigModel',
                  name: model2.name,
                  serialized: jsonEncode(model2.toJson()),
                  createdAt: model2.createdAt,
                ),
              ]);

      // Mock first model deletion to succeed, second to fail
      when(() => mockDb.deleteConfig('model-1')).thenAnswer((_) async {});
      when(() => mockDb.deleteConfig('model-2'))
          .thenThrow(Exception('Model deletion failed'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Model deletion failed'),
        )),
      );

      // Verify that the transaction was attempted
      verify(() => mockDb.transaction<int>(any())).called(1);
    });

    test('should rollback transaction when provider deletion fails', () async {
      // Arrange
      const providerId = 'provider-delete-fail';

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => [
                AiConfigDbEntity(
                  id: model.id,
                  type: 'AiConfigModel',
                  name: model.name,
                  serialized: jsonEncode(model.toJson()),
                  createdAt: model.createdAt,
                ),
              ]);

      // Mock model deletion to succeed, provider deletion to fail
      when(() => mockDb.deleteConfig('model-1')).thenAnswer((_) async {});
      when(() => mockDb.deleteConfig(providerId))
          .thenThrow(Exception('Provider deletion failed'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to delete provider $providerId'),
        )),
      );

      // Verify that the transaction was attempted
      verify(() => mockDb.transaction<int>(any())).called(1);
    });

    test('should use transaction for successful deletions', () async {
      // Arrange
      const providerId = 'provider-transaction';

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name))
          .thenAnswer((_) async => [
                AiConfigDbEntity(
                  id: model.id,
                  type: 'AiConfigModel',
                  name: model.name,
                  serialized: jsonEncode(model.toJson()),
                  createdAt: model.createdAt,
                ),
              ]);

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final deletedCount =
          await repository.deleteInferenceProviderWithModels(providerId);

      // Assert
      expect(deletedCount, equals(1));

      // Verify that the transaction was used
      verify(() => mockDb.transaction<int>(any())).called(1);

      // Verify deletions happened within the transaction
      verify(() => mockDb.deleteConfig('model-1')).called(1);
      verify(() => mockDb.deleteConfig(providerId)).called(1);
    });
  });
}
