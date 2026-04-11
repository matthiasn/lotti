import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ThinkingDisclosure extends StatefulWidget {
  const ThinkingDisclosure({
    required this.thinking,
    super.key,
  });

  final String thinking;

  @override
  State<ThinkingDisclosure> createState() => ThinkingDisclosureState();
}

class ThinkingDisclosureState extends State<ThinkingDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = context.messages;
    final toggleLabel = _expanded
        ? messages.thinkingDisclosureHide
        : messages.thinkingDisclosureShow;
    final stateLabel = _expanded
        ? messages.thinkingDisclosureStateExpanded
        : messages.thinkingDisclosureStateCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$toggleLabel, $stateLabel',
          button: true,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  setState(() => _expanded = !_expanded),
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  setState(() => _expanded = !_expanded),
            },
            child: Focus(
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      toggleLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.designTokens.colors.interactive.enabled
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: SelectionArea(
                  child: GptMarkdown(widget.thinking),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: messages.thinkingDisclosureCopy,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size.square(32),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.thinking),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(messages.thinkingDisclosureCopied),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
