import 'dart:convert';
import 'dart:io';

/// Exception thrown when a Toxiproxy API call fails.
class ToxiproxyException implements Exception {
  ToxiproxyException(this.message);
  final String message;

  @override
  String toString() => 'ToxiproxyException: $message';
}

/// Controller for Toxiproxy to simulate network conditions during tests.
///
/// Toxiproxy API documentation: https://github.com/Shopify/toxiproxy#http-api
class ToxiproxyController {
  ToxiproxyController({
    this.baseUrl = 'http://localhost:8474',
  });

  final String baseUrl;
  final HttpClient _client = HttpClient();

  /// Default proxy name for Dendrite
  static const String dendriteProxy = 'dendrite-proxy';

  /// Create a proxy from toxiproxy to dendrite
  Future<void> createProxy({
    String name = dendriteProxy,
    String listen = '0.0.0.0:18008',
    String upstream = 'dendrite:8008',
  }) async {
    final body = jsonEncode({
      'name': name,
      'listen': listen,
      'upstream': upstream,
      'enabled': true,
    });

    final request = await _client.postUrl(Uri.parse('$baseUrl/proxies'));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    await response.drain<void>();

    if (response.statusCode != 201 && response.statusCode != 200) {
      // Proxy might already exist, try to enable it
      await enableProxy(name);
    }
  }

  /// Enable a proxy
  ///
  /// Throws [ToxiproxyException] if the request fails.
  Future<void> enableProxy(String name) async {
    final body = jsonEncode({'enabled': true});
    final request = await _client.postUrl(Uri.parse('$baseUrl/proxies/$name'));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    await response.drain<void>();

    if (response.statusCode != 200) {
      throw ToxiproxyException(
        'Failed to enable proxy "$name": HTTP ${response.statusCode}',
      );
    }
  }

  /// Disable a proxy (simulates complete network outage)
  Future<void> disableProxy(String name) async {
    final body = jsonEncode({'enabled': false});
    final request = await _client.postUrl(Uri.parse('$baseUrl/proxies/$name'));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    await response.drain<void>();
  }

  /// Get all proxies
  Future<Map<String, dynamic>> getProxies() async {
    final request = await _client.getUrl(Uri.parse('$baseUrl/proxies'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Delete a proxy
  Future<void> deleteProxy(String name) async {
    final request =
        await _client.deleteUrl(Uri.parse('$baseUrl/proxies/$name'));
    final response = await request.close();
    await response.drain<void>();
  }

  /// Add a toxic to a proxy
  ///
  /// Throws [ToxiproxyException] if the request fails.
  Future<void> addToxic({
    required String proxyName,
    required String toxicName,
    required String type,
    required Map<String, dynamic> attributes,
    String stream = 'downstream',
    double toxicity = 1.0,
  }) async {
    final body = jsonEncode({
      'name': toxicName,
      'type': type,
      'stream': stream,
      'toxicity': toxicity,
      'attributes': attributes,
    });

    final request =
        await _client.postUrl(Uri.parse('$baseUrl/proxies/$proxyName/toxics'));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    await response.drain<void>();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ToxiproxyException(
        'Failed to add toxic "$toxicName" to proxy "$proxyName": '
        'HTTP ${response.statusCode}',
      );
    }
  }

  /// Remove a toxic from a proxy
  Future<void> removeToxic({
    required String proxyName,
    required String toxicName,
  }) async {
    final request = await _client
        .deleteUrl(Uri.parse('$baseUrl/proxies/$proxyName/toxics/$toxicName'));
    final response = await request.close();
    await response.drain<void>();
  }

  /// Remove all toxics from a proxy
  Future<void> removeAllToxics(String proxyName) async {
    final request =
        await _client.getUrl(Uri.parse('$baseUrl/proxies/$proxyName/toxics'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final toxics = jsonDecode(body) as List<dynamic>;

    for (final toxic in toxics) {
      final toxicMap = toxic as Map<String, dynamic>;
      final name = toxicMap['name'] as String;
      await removeToxic(proxyName: proxyName, toxicName: name);
    }
  }

  // --- Convenience methods for common network conditions ---

  /// Add latency to all requests (simulates slow network)
  Future<void> addLatency(
    String proxyName, {
    required int latencyMs,
    int jitterMs = 0,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'latency_downstream',
      type: 'latency',
      attributes: {
        'latency': latencyMs,
        'jitter': jitterMs,
      },
    );
  }

  /// Add latency to upstream (request) direction
  Future<void> addUpstreamLatency(
    String proxyName, {
    required int latencyMs,
    int jitterMs = 0,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'latency_upstream',
      type: 'latency',
      stream: 'upstream',
      attributes: {
        'latency': latencyMs,
        'jitter': jitterMs,
      },
    );
  }

  /// Limit bandwidth (simulates congested network)
  ///
  /// The [bytesPerSecond] parameter specifies the desired throughput limit.
  /// Note: Toxiproxy's bandwidth toxic expects the rate in KB/s, so this
  /// method converts bytes/s to KB/s by dividing by 1000.
  ///
  /// Example: `limitBandwidth(proxyName, bytesPerSecond: 10000)` limits to ~10 KB/s.
  Future<void> limitBandwidth(
    String proxyName, {
    required int bytesPerSecond,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'bandwidth_downstream',
      type: 'bandwidth',
      attributes: {
        'rate':
            bytesPerSecond ~/ 1000, // Convert bytes/s to KB/s for Toxiproxy API
      },
    );
  }

  /// Simulate connection timeout after delay
  Future<void> addTimeout(
    String proxyName, {
    required int timeoutMs,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'timeout_downstream',
      type: 'timeout',
      attributes: {
        'timeout': timeoutMs,
      },
    );
  }

  /// Simulate slow close (connection lingers)
  Future<void> addSlowClose(
    String proxyName, {
    required int delayMs,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'slow_close_downstream',
      type: 'slow_close',
      attributes: {
        'delay': delayMs,
      },
    );
  }

  /// Slice data into smaller chunks (simulates packet fragmentation)
  Future<void> addSlicer(
    String proxyName, {
    required int avgBytesPerChunk,
    int delayBetweenChunksUs = 0,
    int sizeVariation = 0,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'slicer_downstream',
      type: 'slicer',
      attributes: {
        'average_size': avgBytesPerChunk,
        'size_variation': sizeVariation,
        'delay': delayBetweenChunksUs,
      },
    );
  }

  /// Reset connection after specified bytes (simulates network cut)
  Future<void> addLimitData(
    String proxyName, {
    required int bytes,
  }) async {
    await addToxic(
      proxyName: proxyName,
      toxicName: 'limit_data_downstream',
      type: 'limit_data',
      attributes: {
        'bytes': bytes,
      },
    );
  }

  /// Cut connection entirely (simulates offline)
  Future<void> disconnect(String proxyName) async {
    await disableProxy(proxyName);
  }

  /// Restore normal connectivity
  Future<void> reconnect(String proxyName) async {
    await enableProxy(proxyName);
  }

  /// Reset to clean state - remove all toxics and enable proxy
  Future<void> reset(String proxyName) async {
    try {
      await removeAllToxics(proxyName);
    } catch (_) {
      // Ignore errors if proxy doesn't exist
    }
    try {
      await enableProxy(proxyName);
    } catch (_) {
      // Ignore errors if proxy doesn't exist
    }
  }

  /// Full reset - delete and recreate proxy
  Future<void> resetAll() async {
    try {
      await deleteProxy(dendriteProxy);
    } catch (_) {
      // Ignore errors if proxy doesn't exist
    }
    await createProxy();
  }

  /// Setup the default proxy for testing
  Future<void> setup() async {
    await createProxy();
  }

  /// Cleanup - close the HTTP client
  void close() {
    _client.close();
  }
}
