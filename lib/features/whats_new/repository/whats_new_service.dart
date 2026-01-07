import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/util/whats_new_markdown_parser.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Service for fetching "What's New" content from a remote repository.
///
/// The content is hosted on GitHub and follows this structure:
/// - `index.json`: List of available releases
/// - `{version}/content.md`: Markdown content for each release
/// - `{version}/banner.jpg`: Banner image for each release
class WhatsNewService {
  /// Creates a new [WhatsNewService].
  ///
  /// [httpClient] can be provided for testing purposes.
  WhatsNewService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Base URL for the What's New content repository.
  static const String baseUrl =
      'https://raw.githubusercontent.com/matthiasn/lotti-docs/main/whats-new';

  /// Timeout for HTTP requests.
  static const Duration timeout = Duration(seconds: 10);

  /// Fetches the index of available releases.
  ///
  /// Returns a list of [WhatsNewRelease] objects sorted by date descending,
  /// or `null` if the fetch fails.
  Future<List<WhatsNewRelease>?> fetchIndex() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/index.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final releasesJson = json['releases'] as List<dynamic>?;

        if (releasesJson == null) {
          return null;
        }

        final releases = releasesJson
            .map((e) => WhatsNewRelease.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return releases;
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'WHATS_NEW',
        subDomain: 'fetchIndex',
      );
    }

    return null;
  }

  /// Fetches and parses the content for a specific release.
  ///
  /// Returns a [WhatsNewContent] object with parsed markdown sections,
  /// or `null` if the fetch fails.
  Future<WhatsNewContent?> fetchContent(WhatsNewRelease release) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/${release.folder}/content.md'),
        headers: {'Accept': 'text/plain'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return WhatsNewMarkdownParser.parse(
          markdown: response.body,
          release: release,
          baseUrl: baseUrl,
        );
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'WHATS_NEW',
        subDomain: 'fetchContent',
      );
    }

    return null;
  }
}
