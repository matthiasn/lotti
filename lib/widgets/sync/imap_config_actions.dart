import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/themes/theme.dart';
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

        return Center(
          child: state.maybeWhen(
            configured: (_, __) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: styleConfig().alarm,
            ),
            imapSaved: (_) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: styleConfig().alarm,
            ),
            imapValid: (_) => FadeInButton(
              key: const Key('settingsSyncSaveButton'),
              localizations.settingsSyncSaveButton,
              textColor: styleConfig().cardColor,
              onPressed: syncConfigCubit.saveImapConfig,
            ),
            imapTesting: (_) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: styleConfig().alarm,
            ),
            imapInvalid: (_, String errorMessage) => FadeInButton(
              key: const Key('settingsSyncDeleteImapButton'),
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: styleConfig().alarm,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
