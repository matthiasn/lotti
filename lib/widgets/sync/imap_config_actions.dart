import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/misc/buttons.dart';

class ImapConfigActions extends StatelessWidget {
  const ImapConfigActions({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        final syncConfigCubit = context.read<SyncConfigCubit>();
        void maybePop() => Navigator.of(context).maybePop();

        void deleteConfig() {
          syncConfigCubit.deleteImapConfig();
          maybePop();
        }

        final errorColor = Theme.of(context).colorScheme.error;

        return Center(
          child: state.maybeWhen(
            configured: (_, __) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: errorColor,
            ),
            imapSaved: (_) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: errorColor,
            ),
            imapValid: (_) => FadeInButton(
              key: const Key('settingsSyncSaveButton'),
              localizations.settingsSyncSaveButton,
              textColor: cardColor,
              onPressed: syncConfigCubit.saveImapConfig,
            ),
            imapTesting: (_) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: errorColor,
            ),
            imapInvalid: (_, String errorMessage) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: errorColor,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
