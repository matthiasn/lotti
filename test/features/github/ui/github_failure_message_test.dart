import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final en = AppLocalizationsEn();

  test('every failure has its own message', () {
    final messages = {
      for (final kind in GitHubFailureKind.values)
        gitHubFailureMessage(en, kind),
    };
    expect(messages, hasLength(GitHubFailureKind.values.length));
    expect(messages.every((m) => m.isNotEmpty), isTrue);
  });

  test('a rate limit says when GitHub will be asked again, in local time', () {
    final retryAt = DateTime(2024, 3, 15, 14, 30);
    expect(
      gitHubFailureMessage(
        en,
        GitHubFailureKind.rateLimited,
        retryAt: retryAt,
      ),
      "GitHub's rate limit is reached. Lotti asks again after 14:30.",
    );
    expect(
      gitHubFailureMessage(
        AppLocalizationsDe(),
        GitHubFailureKind.rateLimited,
        retryAt: retryAt,
      ),
      'Das Rate-Limit von GitHub ist erreicht. Lotti fragt ab 14:30 wieder.',
    );
    expect(
      gitHubFailureMessage(en, GitHubFailureKind.rateLimited),
      "GitHub's rate limit is reached. Try again later.",
    );
  });
}
