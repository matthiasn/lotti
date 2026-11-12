import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the starter prompts.
@visibleForTesting
abstract final class FrontStarterPromptsKeys {
  static const Key dueToday = Key('front-starter-due-today');
  static const Key overdue = Key('front-starter-overdue');
  static const Key thisWeek = Key('front-starter-this-week');
}

/// A first move for a conversation not begun: a few questions she answers
/// well, as the outlined buttons her clarifying questions offer
/// (`FrontAskOptionsRow`). A tap sends the question in its own words, as
/// typing it would.
class FrontStarterPrompts extends StatelessWidget {
  const FrontStarterPrompts({
    required this.onChosen,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onChosen;

  /// False while a turn is in flight — a second tap would queue a second
  /// turn — and while the field holds words of the user's own, which a send
  /// would empty.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final prompts = {
      FrontStarterPromptsKeys.dueToday: messages.frontChatStarterDueToday,
      FrontStarterPromptsKeys.overdue: messages.frontChatStarterOverdue,
      FrontStarterPromptsKeys.thisWeek: messages.frontChatStarterThisWeek,
    };
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        for (final MapEntry(:key, value: prompt) in prompts.entries)
          DesignSystemButton(
            key: key,
            label: prompt,
            variant: DesignSystemButtonVariant.outlined,
            size: DesignSystemButtonSize.medium,
            onPressed: enabled ? () => onChosen(prompt) : null,
          ),
      ],
    );
  }
}
