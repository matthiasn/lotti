import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_contact_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/support_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Paths of the bundled brand marks.
///
/// Both travel as vector assets rather than font glyphs: Material Design Icons
/// has no Discord glyph at all, and deprecated its GitHub one. Each file is the
/// monochrome official mark, tinted at render time from the ambient [IconTheme]
/// so it tracks the row's colour like a font glyph would.
const githubIconAsset = 'assets/icons/github.svg';
const discordIconAsset = 'assets/icons/discord.svg';

/// Keys on the row's four targets, so tests and screenshot harnesses can
/// address a specific destination without depending on which icon font or
/// asset happens to back it.
@visibleForTesting
const contactSupportEmailKey = Key('contact-support-email');
@visibleForTesting
const contactSupportManualKey = Key('contact-support-manual');
@visibleForTesting
const contactSupportGithubKey = Key('contact-support-github');
@visibleForTesting
const contactSupportDiscordKey = Key('contact-support-discord');

/// The app's Contact Us footer, wired to its real destinations.
///
/// Sits at the bottom of both navigation surfaces: pinned beneath Settings in
/// the desktop sidebar, and closing the mobile More sheet. Everything visual
/// lives in [DesignSystemContactRow]; this widget only supplies the localized
/// wording and the four destinations.
///
/// The written affordance opens a `mailto:` — email is the deliberate first
/// step, with the Manual, the repository, and the community invite as the
/// glyphs beside it.
class ContactSupportRow extends ConsumerWidget {
  const ContactSupportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;

    return DesignSystemContactRow(
      label: messages.contactUsLabel,
      // The one row here that is not a brand mark, so it takes the plain
      // envelope: it says "this opens mail" without competing with the three
      // logos beside it.
      labelIcon: MdiIcons.emailOutline,
      labelKey: contactSupportEmailKey,
      onLabelPressed: () => unawaited(
        _launchSupportUri(
          contactEmailUri(subject: messages.contactUsEmailSubject),
        ),
      ),
      actions: [
        DesignSystemContactAction(
          icon: const Icon(MdiIcons.bookOpenPageVariantOutline),
          label: messages.navSidebarManualLabel,
          iconKey: contactSupportManualKey,
          // The Manual's URL is locale-aware and owned by the manual-language
          // controller — the same resolver the Settings tree row uses — but it
          // opens through this row's guarded launcher like its three siblings.
          onPressed: () =>
              unawaited(_launchSupportUri(manualUriForCurrentLocale(ref))),
        ),
        DesignSystemContactAction(
          icon: const _BrandGlyph(asset: githubIconAsset),
          label: messages.contactUsGithubLabel,
          iconKey: contactSupportGithubKey,
          onPressed: () =>
              unawaited(_launchSupportUri(Uri.parse(lottiGithubUrl))),
        ),
        DesignSystemContactAction(
          icon: const _BrandGlyph(asset: discordIconAsset),
          label: messages.contactUsDiscordLabel,
          iconKey: contactSupportDiscordKey,
          onPressed: () =>
              unawaited(_launchSupportUri(Uri.parse(lottiDiscordInviteUrl))),
        ),
      ],
    );
  }
}

/// Launches [uri] in the platform's handler, reporting rather than throwing
/// when there is nothing to open it with.
///
/// A desktop without a configured mail client is the case that matters:
/// `launchUrl` throws there, and because the row fires these without awaiting,
/// an uncaught rejection would surface as an unhandled async error rather than
/// as the harmless no-op the user experiences. A `false` return — the launcher
/// declining without throwing — is the same outcome and is reported the same
/// way.
Future<void> _launchSupportUri(Uri uri) async {
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _reportLaunchFailure(uri, StateError('launcher declined $uri'));
    }
  } on Object catch (error, stackTrace) {
    _reportLaunchFailure(uri, error, stackTrace);
  }
}

/// Reported through [DomainLogger.error] rather than `log`, which is gated on
/// the navigation domain being enabled — a link the user pressed and that did
/// nothing is exactly the report that must survive a disabled domain.
void _reportLaunchFailure(Uri uri, Object error, [StackTrace? stackTrace]) {
  if (!getIt.isRegistered<DomainLogger>()) return;
  getIt<DomainLogger>().error(
    LogDomain.navigation,
    error,
    stackTrace: stackTrace,
    subDomain: 'ContactSupportRow',
    message: 'Could not launch ${uri.scheme} link',
  );
}

/// A bundled monochrome brand mark, sized and tinted from the ambient
/// [IconTheme] so it matches the glyphs it sits beside without repeating their
/// values.
///
/// Reading the theme in its *own* `build` is the point: the enclosing
/// [DesignSystemContactRow] installs the `IconTheme` below the call site that
/// constructs these, so a glyph resolved eagerly at construction would miss it
/// and fall back.
class _BrandGlyph extends StatelessWidget {
  const _BrandGlyph({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? IconSizes.m;
    final color =
        iconTheme.color ?? context.designTokens.colors.text.mediumEmphasis;

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
