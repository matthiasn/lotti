import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';

class ImapConfigStatus extends StatelessWidget {
  const ImapConfigStatus({
    super.key,
    this.showText = true,
  });

  final bool showText;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showText)
                state.when(
                  configured: (_, __) =>
                      StatusText(loc.syncAssistantStatusSuccess),
                  imapSaved: (_) => StatusText(loc.syncAssistantStatusSaved),
                  imapValid: (_) => StatusText(loc.syncAssistantStatusValid),
                  imapTesting: (_) =>
                      StatusText(loc.syncAssistantStatusTesting),
                  imapInvalid: (_, String errorMessage) =>
                      StatusText(errorMessage),
                  loading: () => StatusText(loc.syncAssistantStatusLoading),
                  generating: () =>
                      StatusText(loc.syncAssistantStatusGenerating),
                  empty: () => StatusText(loc.syncAssistantStatusEmpty),
                ),
              const SizedBox(width: 10),
              state.when(
                configured: (_, __) => StatusIndicator(
                  Theme.of(context).colorScheme.primary,
                  semanticsLabel: 'IMAP configured',
                ),
                imapValid: (_) => StatusIndicator(
                  Theme.of(context).colorScheme.primary,
                  semanticsLabel: 'IMAP config valid',
                ),
                imapSaved: (_) => StatusIndicator(
                  Theme.of(context).colorScheme.primary,
                  semanticsLabel: 'IMAP config saved',
                ),
                imapTesting: (_) => StatusIndicator(
                  Theme.of(context).primaryColorLight,
                  semanticsLabel: 'Testing connection',
                ),
                imapInvalid: (_, __) => StatusIndicator(
                  Theme.of(context).colorScheme.error,
                  semanticsLabel: 'IMAP error',
                ),
                loading: () => const StatusIndicator(
                  Colors.grey,
                  semanticsLabel: 'Loading',
                ),
                generating: () => const StatusIndicator(
                  Colors.grey,
                  semanticsLabel: 'Generating key',
                ),
                empty: () => const StatusIndicator(
                  Colors.grey,
                  semanticsLabel: 'IMAP config empty',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatusText extends StatelessWidget {
  const StatusText(
    this.text, {
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        text,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  const StatusIndicator(
    this.statusColor, {
    required this.semanticsLabel,
    super.key,
  });

  final Color statusColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor,
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
