import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Hands a contact channel to the platform's dialer, message composer or mail
/// client (plan v2 phase 7 item 4).
///
/// An interface so the quick-action buttons can be tested without a platform
/// channel, and so the post-call marker written alongside a launch is
/// observable in tests.
abstract class ContactLauncher {
  /// Whether the platform can open [action] for [channel] right now.
  ///
  /// False when the channel/action pair produces no URI, or when nothing on
  /// the device handles the scheme — a tablet with no dialer, a desktop with
  /// no mail client. Callers use this to decide whether to render the button
  /// at all, so a user never presses something that cannot work.
  Future<bool> canLaunch(ContactChannel channel, ContactAction action);

  /// Opens [action] for [channel]. Returns whether the platform accepted it.
  Future<bool> launch(ContactChannel channel, ContactAction action);
}

/// The `url_launcher` implementation.
class UrlLauncherContactLauncher implements ContactLauncher {
  UrlLauncherContactLauncher({
    DomainLogger? logger,
    Future<bool> Function(Uri)? canLaunchUrl,
    Future<bool> Function(Uri)? launchUrl,
  }) : _injectedLogger = logger,
       _canLaunchUrl = canLaunchUrl ?? launcher.canLaunchUrl,
       _launchUrl = launchUrl ?? _defaultLaunch;

  final DomainLogger? _injectedLogger;
  final Future<bool> Function(Uri) _canLaunchUrl;
  final Future<bool> Function(Uri) _launchUrl;

  static Future<bool> _defaultLaunch(Uri uri) =>
      launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);

  DomainLogger? get _logger {
    if (_injectedLogger != null) return _injectedLogger;
    return getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null;
  }

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async {
    final uri = contactChannelUri(channel, action);
    if (uri == null) return false;
    return _guard('canLaunch', uri, () => _canLaunchUrl(uri));
  }

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async {
    final uri = contactChannelUri(channel, action);
    if (uri == null) return false;
    return _guard('launch', uri, () => _launchUrl(uri));
  }

  /// A launcher that throws is the desktop-with-no-mail-client case, and it
  /// must read to the user as "nothing happened", not as a crash.
  ///
  /// The report names the scheme only, never the URI: the URI *is* the phone
  /// number or email address, and contact channels do not belong in a log
  /// file any more than they belong in AI context (ADR 0041 §5).
  Future<bool> _guard(
    String operation,
    Uri uri,
    Future<bool> Function() action,
  ) async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      _logger?.error(
        LogDomain.navigation,
        error,
        message: 'contact $operation failed for ${uri.scheme}:',
        stackTrace: stackTrace,
        subDomain: operation,
      );
      return false;
    }
  }
}

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => UrlLauncherContactLauncher(),
  name: 'contactLauncherProvider',
);
