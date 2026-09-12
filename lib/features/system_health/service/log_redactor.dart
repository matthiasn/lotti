/// Scrubs personally identifiable information from log text.
///
/// The logging contract already says a log message is telemetry, never
/// content, but the full error mirror and the exception strings inside it
/// were never meant to leave the device. Everything the system-health tool
/// puts into a digest, hands to a model or copies to the clipboard goes
/// through [redact] first.
///
/// Each rule replaces a match with a stable bracketed placeholder so a reader
/// can still see *that* an identifier was there and correlate repeats:
/// UUIDs keep their first six characters, the same form `DomainLogger`
/// itself writes for ids it sanitises.
class LogRedactor {
  const LogRedactor();

  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  /// Matrix user (`@name:server`) and room / event (`!abc:server`,
  /// `$abc:server`) identifiers.
  static final RegExp _matrixId = RegExp(
    r'(?<![\w.])[@!$][A-Za-z0-9._=\-/+]+:[A-Za-z0-9.\-]+(?::\d+)?',
  );

  static final RegExp _uuid = RegExp(
    r'\b([0-9a-fA-F]{6})[0-9a-fA-F]{2}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
  );

  /// `key=value` / `key: value` pairs whose key names a credential.
  static final RegExp _credentialPair = RegExp(
    r'\b(api[_\-]?key|access[_\-]?token|refresh[_\-]?token|token|secret|'
    r'password|passwd|authorization|cookie|session[_\-]?id)'
    r'(\s*[=:]\s*)("?)(?:bearer\s+)?[^\s,;"]+\3',
    caseSensitive: false,
  );

  static final RegExp _bearer = RegExp(
    r'\b(bearer\s+)[A-Za-z0-9._\-/+=]+',
    caseSensitive: false,
  );

  /// Long opaque hex / base64 runs that can only be keys or hashes.
  static final RegExp _opaqueToken = RegExp(
    r'(?<![A-Za-z0-9/+_\-])(?=[A-Za-z0-9/+_\-]*[A-Za-z])(?=[A-Za-z0-9/+_\-]*\d)'
    r'[A-Za-z0-9/+_\-]{40,}={0,2}(?![A-Za-z0-9/+_\-=])',
  );

  static final RegExp _homePath = RegExp(
    r'(/Users/|/home/|[A-Za-z]:\\Users\\)[^/\\\s]+',
  );

  /// Candidate IPv6 runs; [_looksLikeIpv6] filters clock times such as
  /// `01:32:41`, which share the colon-separated shape.
  static final RegExp _ipv6Candidate = RegExp(
    r'(?<![\w:.])(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}(?![\w:])',
  );

  static bool _looksLikeIpv6(String candidate) {
    if (candidate.contains('::')) return true;
    if (!RegExp('[a-fA-F]').hasMatch(candidate)) return false;
    return candidate.split(':').length >= 3;
  }

  static final RegExp _ipv4 = RegExp(
    r'\b(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}\b',
  );

  /// International phone numbers only. A bare digit run is far too easy to
  /// confuse with counters, timestamps and ids, so the rule requires `+`.
  static final RegExp _phone = RegExp(r'(?<![\w.])\+\d[\d\s().\-]{7,}\d\b');

  static final RegExp _urlQuery = RegExp(r'(https?://[^\s?#]+)\?[^\s#]*');

  static final RegExp _urlUserInfo = RegExp(r'(https?://)[^\s/@]+@');

  /// Returns [text] with every recognised identifier replaced.
  String redact(String text) {
    if (text.isEmpty) return text;
    var result = text;
    result = result.replaceAllMapped(
      _urlUserInfo,
      (m) => '${m.group(1)}[credentials]@',
    );
    result = result.replaceAllMapped(_urlQuery, (m) => '${m.group(1)}?[query]');
    result = result.replaceAll(_email, '[email]');
    result = result.replaceAll(_matrixId, '[matrix-id]');
    result = result.replaceAllMapped(_uuid, (m) => '[id:${m.group(1)}]');
    result = result.replaceAllMapped(
      _credentialPair,
      (m) => '${m.group(1)}${m.group(2)}[redacted]',
    );
    result = result.replaceAllMapped(_bearer, (m) => '${m.group(1)}[redacted]');
    result = result.replaceAll(_opaqueToken, '[token]');
    result = result.replaceAllMapped(_homePath, (m) => '${m.group(1)}[user]');
    result = result.replaceAll(_ipv4, '[ip]');
    result = result.replaceAllMapped(
      _ipv6Candidate,
      (m) => _looksLikeIpv6(m.group(0)!) ? '[ip]' : m.group(0)!,
    );
    result = result.replaceAll(_phone, '[phone]');
    return result;
  }
}
