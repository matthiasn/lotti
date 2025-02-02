import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

void main() {
  group('CategoriesRepository', () {
    late MockPersistenceLogic mockPersistenceLogic;
    late CategoriesRepository repository;

    setUp(() {
      mockPersistenceLogic = MockPersistenceLogic();
      repository = CategoriesRepository(mockPersistenceLogic);
      registerFallbackValue(FakeCategoryDefinition());
    });

    test('createCategory calls persistenceLogic.upsertEntityDefinition',
        () async {
      // Arrange
      when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
          .thenAnswer((_) async => 1);

      const name = 'Test Category';
      const color = '#FF0000';

      // Act
      final category = await repository.createCategory(
        name: name,
        color: color,
      );

      // Assert
      verify(() => mockPersistenceLogic.upsertEntityDefinition(any()))
          .called(1);

      // Verify the category properties
      expect(category.name, equals(name));
      expect(category.color, equals(color));
      expect(category.id, isNotEmpty);
      expect(category.createdAt, isNotNull);
      expect(category.updatedAt, isNotNull);
      expect(category.vectorClock, equals(null));
    });

    test('createCategory returns the created category', () async {
      // Arrange
      when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
          .thenAnswer((_) async => 1);

      // Act
      final category = await repository.createCategory(
        name: 'Test',
        color: '#000000',
      );

      // Assert
      expect(category, isA<CategoryDefinition>());
      expect(category.name, equals('Test'));
      expect(category.color, equals('#000000'));
    });
  });
}
