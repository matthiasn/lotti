import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/model_catalog_mapping.dart';

void main() {
  group('ModelCatalogMapping.redactedEndpoint', () {
    test('keeps host and path but drops userinfo and query', () {
      final uri = Uri.parse('https://user:pw@api.example.com/v1/models?key=sk');
      expect(
        ModelCatalogMapping.redactedEndpoint(uri),
        'api.example.com/v1/models',
      );
    });

    test('labels a host-less URI as <local>', () {
      final uri = Uri(path: '/v1beta/models');
      expect(
        ModelCatalogMapping.redactedEndpoint(uri),
        '<local>/v1beta/models',
      );
    });
  });

  group('ModelCatalogMapping.addUniqueModality', () {
    test('adds a new modality and de-duplicates', () {
      final modalities = <Modality>[Modality.text];
      ModelCatalogMapping.addUniqueModality(modalities, Modality.image);
      ModelCatalogMapping.addUniqueModality(modalities, Modality.text);
      expect(modalities, [Modality.text, Modality.image]);
    });
  });

  group('ModelCatalogMapping.truthy', () {
    test('coerces bools, numbers and strings', () {
      expect(ModelCatalogMapping.truthy(true), isTrue);
      expect(ModelCatalogMapping.truthy(false), isFalse);
      expect(ModelCatalogMapping.truthy(1), isTrue);
      expect(ModelCatalogMapping.truthy(0), isFalse);
      expect(ModelCatalogMapping.truthy('TRUE'), isTrue);
      expect(ModelCatalogMapping.truthy('nope'), isFalse);
      expect(ModelCatalogMapping.truthy(null), isFalse);
    });
  });

  group('ModelCatalogMapping.integerValue', () {
    test('coerces ints, numbers and numeric strings', () {
      expect(ModelCatalogMapping.integerValue(5), 5);
      expect(ModelCatalogMapping.integerValue(5.9), 5);
      expect(ModelCatalogMapping.integerValue('42'), 42);
      expect(ModelCatalogMapping.integerValue('nope'), isNull);
      expect(ModelCatalogMapping.integerValue(null), isNull);
    });
  });

  group('ModelCatalogMapping.humanizeModelId', () {
    test('title-cases the leaf and upper-cases acronyms and numbers', () {
      expect(
        ModelCatalogMapping.humanizeModelId(
          'models/gemini-4-pro',
          acronyms: {'AI'},
        ),
        'Gemini 4 Pro',
      );
      expect(
        ModelCatalogMapping.humanizeModelId('gpt-6', acronyms: {'GPT'}),
        'GPT 6',
      );
    });

    test('falls back to the raw id when the humanized form is empty', () {
      expect(ModelCatalogMapping.humanizeModelId('---'), '---');
    });
  });

  group('ModelCatalogMapping.extractErrorMessage', () {
    test('reads error.message', () {
      expect(
        ModelCatalogMapping.extractErrorMessage(
          '{"error": {"message": "bad key"}}',
          401,
          providerLabel: 'Gemini',
        ),
        'bad key',
      );
    });

    test('reads a string error and a top-level message', () {
      expect(
        ModelCatalogMapping.extractErrorMessage(
          '{"error": "nope"}',
          400,
          providerLabel: 'OpenAI',
        ),
        'nope',
      );
      expect(
        ModelCatalogMapping.extractErrorMessage(
          '{"message": "top level"}',
          400,
          providerLabel: 'OpenAI',
        ),
        'top level',
      );
    });

    test('falls back to a status-only message on an empty body', () {
      expect(
        ModelCatalogMapping.extractErrorMessage(
          '',
          500,
          providerLabel: 'OpenAI',
        ),
        'OpenAI API error (HTTP 500)',
      );
    });

    test('clips an unparsable body to maxLength with an ellipsis', () {
      final body = 'x' * 200;
      final message = ModelCatalogMapping.extractErrorMessage(
        body,
        500,
        providerLabel: 'Gemini',
        maxLength: 10,
      );
      expect(message, '${'x' * 10}…');
    });

    test('returns a short unparsable body verbatim', () {
      expect(
        ModelCatalogMapping.extractErrorMessage(
          'boom',
          500,
          providerLabel: 'OpenAI',
        ),
        'boom',
      );
    });
  });
}
