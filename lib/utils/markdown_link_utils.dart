import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles taps on links in markdown content by launching the URL externally.
///
/// Skips launch for empty URLs or URLs without a scheme (e.g. no `https://`).
Future<void> handleMarkdownLinkTap(String url, String title) async {
  if (url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Builds a styled markdown link widget with underline and pointer cursor.
///
/// The [linkColor] defaults to the theme's primary color when not specified.
Widget buildMarkdownLink(
  BuildContext context,
  InlineSpan text,
  String url,
  TextStyle style, {
  Color? linkColor,
}) {
  final color = linkColor ?? Theme.of(context).colorScheme.primary;
  return Semantics(
    link: true,
    child: InkWell(
      onTap: () => handleMarkdownLinkTap(url, ''),
      mouseCursor: SystemMouseCursors.click,
      child: Text.rich(
        TextSpan(
          children: [text],
          style: style.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    ),
  );
}
