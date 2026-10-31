import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/mistral_error_body.dart';

void main() {
  // Mistral's answer to `reasoning_effort: none` for Large 4.
  final reasoningEffortError = jsonEncode({
    'object': 'error',
    'message':
        'reasoning_effort none is not supported for this model, supported '
        "values: [<ReasoningEffort.high: 'high'>]",
    'type': 'invalid_request_invalid_args',
    'param': null,
    'code': '3051',
    'raw_status_code': 400,
  });

  group('mistralErrorFields', () {
    test('keeps type and code, drops the message and a null param', () {
      expect(
        mistralErrorFields(reasoningEffortError),
        'type: invalid_request_invalid_args, code: 3051',
      );
    });

    test('keeps a param name and a numeric code', () {
      expect(
        mistralErrorFields(
          jsonEncode({'type': 'invalid_request', 'code': 2, 'param': 'tools'}),
        ),
        'type: invalid_request, code: 2, param: tools',
      );
    });

    test('skips a value that is not a short identifier, so no prompt text '
        'can slip through a field', () {
      expect(
        mistralErrorFields(
          jsonEncode({
            'type': 'Describe my holiday photo please',
            'code': 'x' * 65,
            'param': {'nested': 'value'},
          }),
        ),
        isNull,
      );
    });

    test('is null for a body without the fields, a list, or non-JSON', () {
      expect(
        mistralErrorFields(
          jsonEncode({
            'detail': [
              {'msg': 'field required', 'input': 'the user prompt'},
            ],
          }),
        ),
        isNull,
      );
      expect(mistralErrorFields('[1, 2]'), isNull);
      expect(mistralErrorFields('<html>Bad Gateway</html>'), isNull);
      expect(mistralErrorFields(''), isNull);
    });
  });

  group('mistralErrorLogMessage', () {
    test('names the fields and the length, never the body text', () {
      final fields = mistralErrorFields(reasoningEffortError);
      final line = mistralErrorLogMessage(reasoningEffortError, fields);
      expect(
        line,
        'type: invalid_request_invalid_args, code: 3051; '
        'body ${reasoningEffortError.length} chars, rest not logged — it can '
        'echo the prompt',
      );
      expect(line, isNot(contains('not supported')));
    });

    test('says so when the body has no type or code', () {
      expect(
        mistralErrorLogMessage('oops', null),
        startsWith('no error type or code; body 4 chars'),
      );
    });
  });
}
