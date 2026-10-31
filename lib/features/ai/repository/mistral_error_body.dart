import 'dart:convert';

/// The content-free fields of a Mistral error response [body], such as
/// `type: invalid_request_invalid_args, code: 3051`, or null when it has none.
///
/// Mistral's errors carry `type`, `code` and `param` beside a `message`. The
/// first three name what was rejected and never hold user content, so they
/// are safe to log and to show; the message (and a validation error's
/// `detail` list) can quote the request, so it is never read. A value that is
/// not a short identifier is skipped rather than trusted.
String? mistralErrorFields(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final fields = [
    for (final key in const ['type', 'code', 'param'])
      if (decoded[key] case final Object value
          when (value is String || value is num) &&
              _identifier.hasMatch('$value'))
        '$key: $value',
  ];
  return fields.isEmpty ? null : fields.join(', ');
}

/// The log line for a Mistral error [body]: its [fields] (from
/// [mistralErrorFields]) and its length, never its text.
String mistralErrorLogMessage(String body, String? fields) =>
    '${fields ?? 'no error type or code'}; body ${body.length} chars, '
    'rest not logged — it can echo the prompt';

final _identifier = RegExp(r'^[A-Za-z0-9_.\-]{1,64}$');
