import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';

/// Parses markdown content for the What's New feature.
///
/// The markdown is split into sections by horizontal dividers (`---`).
/// The first section becomes the header, and subsequent sections become
/// individual pages in the swipable modal.
class WhatsNewMarkdownParser {
  /// The divider pattern used to split markdown into sections.
  static const String sectionDivider = '\n---\n';

  /// Parses markdown content into a [WhatsNewContent] object.
  ///
  /// - [markdown]: The raw markdown content to parse.
  /// - [release]: The release metadata.
  /// - [baseUrl]: The base URL for resolving relative image paths.
  static WhatsNewContent parse({
    required String markdown,
    required WhatsNewRelease release,
    required String baseUrl,
  }) {
    // Normalize line endings and split by divider
    final normalizedMarkdown = markdown.replaceAll('\r\n', '\n');
    final parts = normalizedMarkdown.split(sectionDivider);

    // First part is the header
    final headerMarkdown = parts.isNotEmpty ? parts.first.trim() : '';

    // Remaining parts are content sections
    final sections = parts
        .skip(1)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Resolve relative image URLs in header and sections
    final resolvedHeader = _resolveImageUrls(
      headerMarkdown,
      baseUrl,
      release.folder,
    );
    final resolvedSections = sections
        .map((section) => _resolveImageUrls(section, baseUrl, release.folder))
        .toList();

    // Construct banner image URL
    final bannerImageUrl = '$baseUrl/${release.folder}/banner.jpg';

    return WhatsNewContent(
      release: release,
      headerMarkdown: resolvedHeader,
      sections: resolvedSections,
      bannerImageUrl: bannerImageUrl,
    );
  }

  /// Resolves relative image URLs in markdown to absolute URLs.
  ///
  /// Matches markdown image syntax `![alt](path)` where path is not an
  /// absolute URI (any scheme, e.g. `http:`, `https:`, `data:`, `file:`) and
  /// not protocol-relative (`//host/...`), then replaces it with the full
  /// release asset URL.
  static String _resolveImageUrls(
    String markdown,
    String baseUrl,
    String folder,
  ) {
    // Pattern: ![alt text](relative/path.png). The negative lookahead rejects
    // any RFC 3986 scheme prefix (`scheme:`) and protocol-relative `//` paths
    // so absolute URIs like `data:`, `file:`, or `//cdn/...` are preserved.
    final imagePattern = RegExp(
      r'!\[([^\]]*)\]\((?!(?:[a-z][a-z0-9+.-]*:|\/\/))([^)]+)\)',
      caseSensitive: false,
    );

    return markdown.replaceAllMapped(imagePattern, (match) {
      final altText = match.group(1) ?? '';
      final relativePath = match.group(2) ?? '';
      return '![$altText]($baseUrl/$folder/$relativePath)';
    });
  }
}
