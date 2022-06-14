import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/theme.dart';

class ImapConfigStatus extends StatelessWidget {
  const ImapConfigStatus({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations loc = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      return SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            state.when(
              (_, __) => const SizedBox.shrink(),
              configured: (_, __) => StatusText(loc.syncAssistantStatusSuccess),
              imapSaved: (_) => StatusText(loc.syncAssistantStatusSaved),
              imapValid: (_) => StatusText(loc.syncAssistantStatusValid),
              imapTesting: (_) => StatusText(loc.syncAssistantStatusTesting),
              imapInvalid: (_, String errorMessage) => StatusText(errorMessage),
              loading: () => StatusText(loc.syncAssistantStatusLoading),
              generating: () => StatusText(loc.syncAssistantStatusGenerating),
              empty: () => StatusText(loc.syncAssistantStatusEmpty),
            ),
            state.when(
              (_, __) => const SizedBox.shrink(),
              configured: (_, __) =>
                  StatusIndicator(AppColors.outboxSuccessColor),
              imapValid: (_) => StatusIndicator(AppColors.outboxSuccessColor),
              imapSaved: (_) => StatusIndicator(AppColors.outboxSuccessColor),
              imapTesting: (_) => StatusIndicator(AppColors.outboxPendingColor),
              imapInvalid: (_, __) => StatusIndicator(AppColors.error),
              loading: () => const StatusIndicator(Colors.grey),
              generating: () => const StatusIndicator(Colors.grey),
              empty: () => const StatusIndicator(Colors.grey),
            ),
          ],
        ),
      );
    });
  }
}

class StatusText extends StatelessWidget {
  const StatusText(
    this.text, {
    Key? key,
  }) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: formLabelStyle);
  }
}

class StatusIndicator extends StatelessWidget {
  const StatusIndicator(
    this.statusColor, {
    Key? key,
  }) : super(key: key);

  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor,
            blurRadius: 8,
            spreadRadius: 2,
          )
        ],
      ),
    );
  }
}
