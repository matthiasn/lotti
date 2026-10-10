import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Why an image of a pull request description was not fetched.
enum PullRequestImageFailure {
  /// The URL is not `https`, or a redirect led off `https`.
  notHttps,

  /// The server did not answer 200 within the redirects allowed.
  status,

  /// The server answered with something that is not an image.
  notAnImage,

  /// The image is larger than [PullRequestImageFetcher.maxBytes].
  tooLarge,

  /// The request did not complete: offline, a timeout, a dropped connection.
  network,
}

/// Thrown by [PullRequestImageFetcher.fetch] with why and for which URL.
class PullRequestImageException implements Exception {
  const PullRequestImageException(this.failure, this.url);

  final PullRequestImageFailure failure;
  final String url;

  @override
  String toString() => 'PullRequestImageException(${failure.name}, $url)';
}

/// Fetches the images a pull request description embeds, each once.
///
/// A description is the pull request's own text, shown only when the user
/// opens its details, so its images are loaded — but from `https` URLs
/// only, redirects included, with nothing of the user's sent along: no
/// token, no cookies. The bytes of each image are kept for the session,
/// within [cacheBytes], so the details reopened, the full-size viewer and
/// attaching the image to the task share one read.
class PullRequestImageFetcher {
  PullRequestImageFetcher({
    http.Client? client,
    this.maxBytes = defaultMaxBytes,
    this.cacheBytes = defaultCacheBytes,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// The largest image fetched: a screenshot is a few megabytes, and a
  /// description is not where a user expects to wait on a download.
  static const int defaultMaxBytes = 20 * 1024 * 1024;

  /// How many bytes of fetched images are kept at once.
  static const int defaultCacheBytes = 64 * 1024 * 1024;

  /// How many redirects a fetch follows before giving up.
  static const int maxRedirects = 5;

  final http.Client _client;
  final int maxBytes;
  final int cacheBytes;
  final Duration timeout;

  /// Fetched bytes by URL, oldest use first.
  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List>>{};
  int _cachedBytes = 0;

  /// The bytes of [url] if it was fetched already, without fetching.
  Uint8List? cached(String url) => _cache[url];

  /// The bytes of the image at [url].
  ///
  /// Throws a [PullRequestImageException] when it cannot be fetched. A URL
  /// being fetched is not fetched again; one that failed is tried again.
  Future<Uint8List> fetch(String url) {
    final hit = _cache.remove(url);
    if (hit != null) {
      // Most recently used, so it is the last to be evicted.
      _cache[url] = hit;
      return Future.value(hit);
    }
    return _inFlight.putIfAbsent(url, () => _fetchOnce(url));
  }

  Future<Uint8List> _fetchOnce(String url) async {
    try {
      final bytes = await _read(url).timeout(
        timeout,
        onTimeout: () => throw PullRequestImageException(
          PullRequestImageFailure.network,
          url,
        ),
      );
      _store(url, bytes);
      return bytes;
    } finally {
      _inFlight.remove(url)?.ignore();
    }
  }

  void _store(String url, Uint8List bytes) {
    if (bytes.length > cacheBytes) return;
    while (_cachedBytes + bytes.length > cacheBytes && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _cachedBytes -= _cache.remove(oldest)!.length;
    }
    _cache[url] = bytes;
    _cachedBytes += bytes.length;
  }

  Future<Uint8List> _read(String url) async {
    var uri = _httpsUri(url);
    for (var redirects = 0; redirects <= maxRedirects; redirects++) {
      final http.StreamedResponse response;
      try {
        response = await _client.send(
          http.Request('GET', uri)..followRedirects = false,
        );
      } on http.ClientException {
        throw PullRequestImageException(PullRequestImageFailure.network, url);
      }
      final location = response.headers['location'];
      if (_isRedirect(response.statusCode) && location != null) {
        // Drain so the connection is reusable, then follow by hand: the
        // package would follow a redirect onto plain http as readily.
        response.stream.drain<void>().ignore();
        uri = _httpsUri(uri.resolve(location).toString(), original: url);
        continue;
      }
      if (response.statusCode != 200) {
        response.stream.drain<void>().ignore();
        throw PullRequestImageException(PullRequestImageFailure.status, url);
      }
      final type = response.headers['content-type'];
      if (type != null && !type.trim().toLowerCase().startsWith('image/')) {
        response.stream.drain<void>().ignore();
        throw PullRequestImageException(
          PullRequestImageFailure.notAnImage,
          url,
        );
      }
      if ((response.contentLength ?? 0) > maxBytes) {
        response.stream.drain<void>().ignore();
        throw PullRequestImageException(PullRequestImageFailure.tooLarge, url);
      }
      return _collect(response.stream, url);
    }
    throw PullRequestImageException(PullRequestImageFailure.status, url);
  }

  /// Reads [stream] into one buffer, giving up as soon as it passes
  /// [maxBytes]: a server that lies about its length does not fill memory.
  Future<Uint8List> _collect(http.ByteStream stream, String url) async {
    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in stream) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw PullRequestImageException(
            PullRequestImageFailure.tooLarge,
            url,
          );
        }
      }
    } on http.ClientException {
      throw PullRequestImageException(PullRequestImageFailure.network, url);
    }
    return builder.takeBytes();
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// [url] as a URI, if it is an `https` one; [original] is the URL the
  /// caller asked for when [url] is a redirect from it.
  static Uri _httpsUri(String url, {String? original}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw PullRequestImageException(
        PullRequestImageFailure.notHttps,
        original ?? url,
      );
    }
    return uri;
  }

  /// Closes the client. The fetcher is not usable afterwards.
  void close() => _client.close();
}
