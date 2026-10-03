import 'package:intl/intl.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// What to tell the user when a GitHub call failed with [kind]; [retryAt]
/// is when a rate-limited device will ask again.
String gitHubFailureMessage(
  AppLocalizations messages,
  GitHubFailureKind kind, {
  DateTime? retryAt,
}) => switch (kind) {
  GitHubFailureKind.noToken => messages.githubFailureNoToken,
  GitHubFailureKind.offline => messages.githubFailureOffline,
  GitHubFailureKind.unauthorized => messages.githubFailureUnauthorized,
  GitHubFailureKind.forbidden => messages.githubFailureForbidden,
  GitHubFailureKind.rateLimited =>
    retryAt == null
        ? messages.githubFailureRateLimitedLater
        : messages.githubFailureRateLimited(
            DateFormat.Hm(messages.localeName).format(retryAt.toLocal()),
          ),
  GitHubFailureKind.notFound => messages.githubFailureNotFound,
  GitHubFailureKind.server => messages.githubFailureServer,
  GitHubFailureKind.invalidResponse => messages.githubFailureInvalidResponse,
};
