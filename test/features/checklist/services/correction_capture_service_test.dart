import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late CorrectionCaptureService service;
  late MockCategoryRepository mockCategoryRepository;

  final testCategory = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
    correctionExamples: [],
  );

  final categoryWithExamples = CategoryDefinition(
    id: 'category-2',
    name: 'Category With Examples',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#00FF00',
    correctionExamples: [
      ChecklistCorrectionExample(
        before: 'existing before',
        after: 'existing after',
        capturedAt: DateTime(2025),
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(testCategory);
  });

  setUp(() {
    mockCategoryRepository = MockCategoryRepository();
    service = CorrectionCaptureService(
      categoryRepository: mockCategoryRepository,
    );
  });

  group('CorrectionCaptureService', () {
    group('captureCorrection', () {
      test('returns noCategory when categoryId is null', () async {
        final result = await service.captureCorrection(
          categoryId: null,
          beforeText: 'before',
          afterText: 'after',
        );

        expect(result, equals(CorrectionCaptureResult.noCategory));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns noChange when texts are identical after normalization',
          () async {
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: '  hello  world  ',
          afterText: 'hello world',
        );

        expect(result, equals(CorrectionCaptureResult.noChange));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns trivialChange for case-only changes on short texts',
          () async {
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'AB',
          afterText: 'ab',
        );

        expect(result, equals(CorrectionCaptureResult.trivialChange));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns categoryNotFound when category does not exist', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => null);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'before text',
          afterText: 'after text',
        );

        expect(result, equals(CorrectionCaptureResult.categoryNotFound));
      });

      test('returns duplicate when same correction already exists', () async {
        when(() => mockCategoryRepository.getCategoryById('category-2'))
            .thenAnswer((_) async => categoryWithExamples);

        final result = await service.captureCorrection(
          categoryId: 'category-2',
          beforeText: 'existing before',
          afterText: 'existing after',
        );

        expect(result, equals(CorrectionCaptureResult.duplicate));
        verifyNever(() => mockCategoryRepository.updateCategory(any()));
      });

      test('successfully captures new correction', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight release',
          afterText: 'TestFlight release',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(captured.correctionExamples, hasLength(1));
        expect(captured.correctionExamples!.first.before,
            equals('test flight release'));
        expect(captured.correctionExamples!.first.after,
            equals('TestFlight release'));
        expect(captured.correctionExamples!.first.capturedAt, isNotNull);
      });

      test('appends to existing corrections', () async {
        when(() => mockCategoryRepository.getCategoryById('category-2'))
            .thenAnswer((_) async => categoryWithExamples);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => categoryWithExamples);

        final result = await service.captureCorrection(
          categoryId: 'category-2',
          beforeText: 'new before',
          afterText: 'new after',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(captured.correctionExamples, hasLength(2));
        expect(captured.correctionExamples!.last.before, equals('new before'));
        expect(captured.correctionExamples!.last.after, equals('new after'));
      });

      test('normalizes whitespace before saving', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: '  test   flight  ',
          afterText: '  TestFlight  ',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(
            captured.correctionExamples!.first.before, equals('test flight'));
        expect(captured.correctionExamples!.first.after, equals('TestFlight'));
      });

      test('returns saveFailed when repository throws', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenThrow(Exception('Database error'));

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'before',
          afterText: 'after',
        );

        expect(result, equals(CorrectionCaptureResult.saveFailed));
      });

      test('captures meaningful case changes for longer texts', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'macos',
          afterText: 'macOS',
        );

        expect(result, equals(CorrectionCaptureResult.success));
      });
    });
  });

  group('CorrectionCaptureResult', () {
    test('has all expected values', () {
      expect(CorrectionCaptureResult.values, hasLength(7));
      expect(
        CorrectionCaptureResult.values,
        containsAll([
          CorrectionCaptureResult.success,
          CorrectionCaptureResult.noCategory,
          CorrectionCaptureResult.noChange,
          CorrectionCaptureResult.trivialChange,
          CorrectionCaptureResult.duplicate,
          CorrectionCaptureResult.categoryNotFound,
          CorrectionCaptureResult.saveFailed,
        ]),
      );
    });
  });
}
