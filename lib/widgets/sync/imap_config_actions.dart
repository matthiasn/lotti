import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';

class ImapConfigActions extends StatelessWidget {
  const ImapConfigActions({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        final syncConfigCubit = context.read<SyncConfigCubit>();

        void deleteConfig() {
          syncConfigCubit.deleteImapConfig();
          context.router.pop();
        }

        return Center(
          child: state.maybeWhen(
            configured: (_, __) => FadeInButton(
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: AppColors.error,
            ),
            imapSaved: (_) => FadeInButton(
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: AppColors.error,
            ),
            imapValid: (_) => FadeInButton(
              localizations.settingsSyncSaveButton,
              textColor: AppColors.headerBgColor,
              onPressed: syncConfigCubit.saveImapConfig,
            ),
            imapTesting: (_) => FadeInButton(
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: AppColors.error,
            ),
            imapInvalid: (_, String errorMessage) => FadeInButton(
              localizations.settingsSyncDeleteImapButton,
              onPressed: deleteConfig,
              primaryColor: AppColors.error,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
