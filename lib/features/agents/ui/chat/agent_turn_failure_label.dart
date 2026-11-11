import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// What an agent chat says about a turn whose wake failed with [cause]: the
/// provider's own words when a provider answered — an empty balance said as
/// such — or null when it did not, for the chat's generic line.
String? agentTurnFailureLabel(AppLocalizations messages, Object? cause) {
  final message = AiErrorUtils.providerMessage(cause);
  if (message == null) return null;
  return AiErrorUtils.isOutOfCredit(cause)
      ? messages.agentChatFailedOutOfCredit(message)
      : messages.agentChatFailedProviderSaid(message);
}
