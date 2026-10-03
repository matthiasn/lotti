import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The only schemes a markdown link may hand to another app. Markdown here is
/// written by models and synced from other devices, so an arbitrary scheme
/// (`file:`, `intent:`, an app's custom handler) must not be one tap away.
const _externalLinkSchemes = <String>{'https', 'http', 'mailto'};

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
/// `https`, `http` and `mailto` links launch via the platform URL launcher;
/// any other scheme, and relative URLs with no stable in-app destination, are
/// ignored.
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
  if (uri != null && _externalLinkSchemes.contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// An image builder for `GptMarkdown.imageBuilder` that never fetches.
///
/// Markdown from a model or another device can carry an image URL built by a
/// prompt injection; rendering it would request that URL — with whatever the
/// URL encodes — the moment the text is shown, without a click. In its place
/// this shows where the image would have come from.
Widget buildBlockedMarkdownImage(
  BuildContext context,
  String imageUrl,
  double? width,
  double? height,
) {
  final tokens = context.designTokens;
  final host = Uri.tryParse(imageUrl)?.host ?? '';
  final label = context.messages.markdownRemoteImageBlocked(
    host.isEmpty ? imageUrl : host,
  );
  final color = tokens.colors.text.lowEmphasis;
  return Semantics(
    label: label,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LottiIcons.imageBroken,
          size: tokens.spacing.step5,
          color: color,
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Link styling for app markdown: [color] in the resting and hover states.
///
/// Pass it as `GptMarkdown.styleSheet`. The package renders each link as a
/// span that wraps, stays selectable and calls `GptMarkdown.onLinkTap`, so
/// only the colour needs setting here. The hover colour is pinned to [color]
/// because the package falls back to red on hover.
GptMarkdownStyleSheet markdownLinkStyleSheet(Color color) {
  return GptMarkdownStyleSheet(
    link: LinkStyle(color: color, hoverColor: color),
  );
}

/// Builds a link for `GptMarkdown.inlineLinkBuilder` as a focusable widget.
///
/// A span link cannot take keyboard focus, so surfaces whose links must be
/// reachable with Tab and Enter, such as answer citations, render them through
/// an [InkWell] instead. Activation goes to `GptMarkdown.onLinkTap`, and the
/// label keeps the colour set by [markdownLinkStyleSheet]. Without an
/// `onLinkTap` the link is inert.
InlineSpan buildFocusableMarkdownLink(LinkBuildDetails link) {
  return link.asWidgetSpan(
    Semantics(
      link: true,
      child: InkWell(
        onTap: link.onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Text.rich(
          // The placeholder already scales its child with the surrounding
          // text. Scaling here too would enlarge inline citations twice.
          textScaler: TextScaler.noScaling,
          TextSpan(style: link.style, children: link.labelSpans),
        ),
      ),
    ),
  );
}
