import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _internalRouteRoots = <String>{
  '/calendar',
  '/dashboards',
  '/habits',
  '/journal',
  '/projects',
  '/settings',
  '/tasks',
};

String? _internalRouteFromMarkdownUrl(String url) {
  if (url.isEmpty) return null;

  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final path = switch (uri.scheme) {
    'lotti' when uri.host.isNotEmpty => '/${uri.host}${uri.path}',
    'lotti' => uri.path,
    '' when uri.path.startsWith('/') => uri.path,
    '' => '',
    _ => '',
  };
  if (path.isEmpty) return null;

  final matchesInternalRoot = _internalRouteRoots.any(
    (root) => path == root || path.startsWith('$root/'),
  );
  if (!matchesInternalRoot) return null;

  return uri.hasQuery ? '$path?${uri.query}' : path;
}

/// Handles taps on links in markdown content.
///
/// App-local routes such as `/tasks/<id>` route through [NavService].
/// External URLs still launch via the platform URL launcher. Other relative
/// URLs are ignored because they have no stable in-app destination.
Future<void> handleMarkdownLinkTap(String url, String title) async {
  if (url.isEmpty) return;
  final internalRoute = _internalRouteFromMarkdownUrl(url);
  if (internalRoute != null) {
    if (getIt.isRegistered<NavService>()) {
      getIt<NavService>().beamToNamed(internalRoute);
    }
    return;
  }

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
