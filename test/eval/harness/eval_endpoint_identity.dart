// Non-secret endpoint identity helpers for live eval provenance.
//
// Eval artifacts must distinguish official providers, local endpoints, and
// OpenAI-compatible proxies without persisting API keys or full prompt payloads.

import 'dart:convert';

import 'package:crypto/crypto.dart';

String evalProviderEndpointOrigin(String baseUrl) {
  final uri = _parseEndpoint(baseUrl);
  if (uri == null) return baseUrl.trim();
  return '${uri.scheme}://${_hostForDisplay(uri.host)}${_port(uri)}';
}

String evalProviderBaseUrlDigest(String baseUrl) {
  return 'sha256:${sha256.convert(utf8.encode(_normalizedBaseUrl(baseUrl)))}';
}

String _normalizedBaseUrl(String baseUrl) {
  final uri = _parseEndpoint(baseUrl);
  if (uri == null) return baseUrl.trim();
  return '${uri.scheme}://${_hostForDisplay(uri.host)}${_port(uri)}'
      '${_normalizedPath(uri.path)}';
}

Uri? _parseEndpoint(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return null;
  return uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    userInfo: '',
    query: '',
    fragment: '',
  );
}

String _hostForDisplay(String host) {
  final normalized = host.toLowerCase();
  if (normalized.contains(':') &&
      !normalized.startsWith('[') &&
      !normalized.endsWith(']')) {
    return '[$normalized]';
  }
  return normalized;
}

String _port(Uri uri) {
  if (!uri.hasPort) return '';
  if (uri.scheme == 'https' && uri.port == 443) return '';
  if (uri.scheme == 'http' && uri.port == 80) return '';
  return ':${uri.port}';
}

String _normalizedPath(String path) {
  var normalized = path.trim();
  while (normalized.endsWith('/') && normalized.length > 1) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized == '/') return '';
  if (normalized.isEmpty) return '';
  return normalized.startsWith('/') ? normalized : '/$normalized';
}
