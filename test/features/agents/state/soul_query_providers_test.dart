import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

class MockSoulDocumentService extends Mock implements SoulDocumentService {}

void main() {
  late MockSoulDocumentService mockService;

  setUp(() {
    mockService = MockSoulDocumentService();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        soulDocumentServiceProvider.overrideWithValue(mockService),
      ],
    );
  }

  group('allSoulDocumentsProvider', () {
    test('returns all souls from service', () async {
      final soul1 = makeTestSoulDocument(id: 'soul-1', displayName: 'Laura');
      final soul2 = makeTestSoulDocument(id: 'soul-2', displayName: 'Tom');
      when(
        () => mockService.getAllSouls(),
      ).thenAnswer((_) async => [soul1, soul2]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(allSoulDocumentsProvider.future);

      expect(result, hasLength(2));
      expect(result[0], isA<SoulDocumentEntity>());
      expect(result[1], isA<SoulDocumentEntity>());
    });

    test('returns empty list when no souls', () async {
      when(() => mockService.getAllSouls()).thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(allSoulDocumentsProvider.future);

      expect(result, isEmpty);
    });
  });

  group('soulDocumentProvider', () {
    test('returns soul by ID', () async {
      final soul = makeTestSoulDocument(id: 'soul-1', displayName: 'Laura');
      when(() => mockService.getSoul('soul-1')).thenAnswer((_) async => soul);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulDocumentProvider('soul-1').future,
      );

      expect(result, isA<SoulDocumentEntity>());
      expect(
        (result! as SoulDocumentEntity).displayName,
        'Laura',
      );
    });

    test('returns null for unknown ID', () async {
      when(() => mockService.getSoul('unknown')).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulDocumentProvider('unknown').future,
      );

      expect(result, isNull);
    });
  });

  group('activeSoulVersionProvider', () {
    test('returns active version for soul', () async {
      final version = makeTestSoulDocumentVersion(
        agentId: 'soul-1',
        version: 3,
      );
      when(
        () => mockService.getActiveSoulVersion('soul-1'),
      ).thenAnswer((_) async => version);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        activeSoulVersionProvider('soul-1').future,
      );

      expect(result, isA<SoulDocumentVersionEntity>());
      expect(
        (result! as SoulDocumentVersionEntity).version,
        3,
      );
    });

    test('returns null when no active version', () async {
      when(
        () => mockService.getActiveSoulVersion('soul-1'),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        activeSoulVersionProvider('soul-1').future,
      );

      expect(result, isNull);
    });
  });

  group('soulVersionHistoryProvider', () {
    test('returns version history for soul', () async {
      final v1 = makeTestSoulDocumentVersion(
        id: 'v1',
        agentId: 'soul-1',
        // ignore: avoid_redundant_argument_values
        version: 1,
      );
      final v2 = makeTestSoulDocumentVersion(
        id: 'v2',
        agentId: 'soul-1',
        version: 2,
      );
      when(
        () => mockService.getVersionHistory('soul-1', limit: -1),
      ).thenAnswer((_) async => [v2, v1]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulVersionHistoryProvider('soul-1').future,
      );

      expect(result, hasLength(2));
      expect(result[0], isA<SoulDocumentVersionEntity>());
    });
  });

  group('soulForTemplateProvider', () {
    test('returns soul version assigned to template', () async {
      final version = makeTestSoulDocumentVersion(
        agentId: 'soul-1',
        version: 2,
      );
      when(
        () => mockService.resolveActiveSoulForTemplate('tpl-1'),
      ).thenAnswer((_) async => version);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulForTemplateProvider('tpl-1').future,
      );

      expect(result, isA<SoulDocumentVersionEntity>());
    });

    test('returns null when no soul assigned', () async {
      when(
        () => mockService.resolveActiveSoulForTemplate('tpl-1'),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        soulForTemplateProvider('tpl-1').future,
      );

      expect(result, isNull);
    });
  });

  group('templatesUsingSoulProvider', () {
    test('returns template IDs using a soul', () async {
      when(
        () => mockService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => ['tpl-1', 'tpl-2']);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templatesUsingSoulProvider('soul-1').future,
      );

      expect(result, ['tpl-1', 'tpl-2']);
    });

    test('returns empty list when no templates use soul', () async {
      when(
        () => mockService.getTemplatesUsingSoul('soul-1'),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templatesUsingSoulProvider('soul-1').future,
      );

      expect(result, isEmpty);
    });
  });
}
