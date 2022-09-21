import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:random_password_generator/random_password_generator.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (Platform.isIOS || Platform.isAndroid) {
      return const EncryptionQrReaderWidget();
    }
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                key: const Key('genKeyButton'),
                state.maybeMap(
                  configured: (_) => localizations.settingsSyncReGenKeyButton,
                  orElse: () => localizations.settingsSyncGenKeyButton,
                ),
                onPressed: () =>
                    context.read<SyncConfigCubit>().generateSharedKey(),
                primaryColor: Colors.red,
              ),
              const SizedBox(height: 32),
              state.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                configured: (ImapConfig imapConfig, String sharedKey) {
                  final syncConfig = SyncConfig(
                    imapConfig: imapConfig,
                    sharedSecret: sharedKey,
                  );
                  final syncCfgJson = json.encode(syncConfig);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        child: GestureDetector(
                          key: const Key('QrImageGestureDetector'),
                          onTap: () async {
                            final password = RandomPasswordGenerator();
                            final randomPassword = password.randomPassword(
                              numbers: true,
                              passwordLength: 32,
                            );

                            void showPassphrase() {
                              showDialog<String>(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title: Text(
                                    randomPassword,
                                    style: monospaceTextStyleLarge(),
                                  ),
                                  actions: <Widget>[
                                    Button(
                                      localizations.settingsSyncCloseButton,
                                      key: const Key('closeButton'),
                                      onPressed: () {
                                        Navigator.pop(context, 'Close');
                                      },
                                      primaryColor: Colors.grey,
                                    ),
                                  ],
                                ),
                              );
                            }

                            await showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: Text(
                                  localizations.settingsSyncCopyCfg,
                                  style: const TextStyle(fontFamily: 'Oswald'),
                                ),
                                content: Text(
                                  localizations.settingsSyncCopyCfgWarning,
                                  style: const TextStyle(fontFamily: mainFont),
                                ),
                                actions: <Widget>[
                                  Button(
                                    localizations.settingsSyncCancelButton,
                                    key: const Key('cancelCopyButton'),
                                    onPressed: () {
                                      Navigator.pop(context, 'Cancel');
                                    },
                                    primaryColor: Colors.grey,
                                  ),
                                  Button(
                                    localizations.settingsSyncCopyButton,
                                    key: const Key('copyButton'),
                                    onPressed: () async {
                                      final b64Secret =
                                          getIt<SyncConfigService>()
                                              .generateKeyFromPassphrase(
                                        randomPassword,
                                      );

                                      final encryptedConfig =
                                          await encryptString(
                                        plainText: syncCfgJson,
                                        b64Secret: b64Secret,
                                      );

                                      await Clipboard.setData(
                                        ClipboardData(text: encryptedConfig),
                                      );

                                      // ignore: use_build_context_synchronously
                                      Navigator.pop(context, 'Copy SyncConfig');
                                      showPassphrase();
                                    },
                                    primaryColor: Colors.red,
                                  ),
                                ],
                              ),
                            );
                          },
                          child: QrImage(
                            data: syncCfgJson,
                            size: 280,
                            key: const Key('QrImage'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const DeleteSyncKeyButton(
                        key: Key('deleteSyncKeyButton'),
                      ),
                    ],
                  );
                },
                loading: () =>
                    StatusTextWidget(localizations.settingsSyncLoadingKey),
                generating: () =>
                    StatusTextWidget(localizations.settingsSyncGenKey),
                empty: () => const EmptyConfigWidget(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EmptyConfigWidget extends StatelessWidget {
  const EmptyConfigWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusText(localizations.settingsSyncNotInitialized),
        const SizedBox(height: 8),
        Button(
          key: const Key('settingsSyncPasteCfg'),
          localizations.settingsSyncPasteCfg,
          onPressed: () {
            var passphrase = '';
            showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: Text(
                  localizations.settingsSyncPasteCfg,
                  style: const TextStyle(fontFamily: 'Oswald'),
                ),
                content: Column(
                  children: [
                    Text(
                      localizations.settingsSyncPasteCfgWarning,
                      style: const TextStyle(fontFamily: mainFont),
                    ),
                    TextField(
                      onChanged: (s) => passphrase = s,
                    ),
                  ],
                ),
                actions: <Widget>[
                  Button(
                    localizations.settingsSyncCancelButton,
                    key: const Key('syncCancelButton'),
                    onPressed: () {
                      Navigator.pop(context, 'Cancel');
                    },
                    primaryColor: Colors.grey,
                  ),
                  Button(
                    localizations.settingsSyncImportButton,
                    key: const Key('syncImportButton'),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final syncConfigCubit = context.read<SyncConfigCubit>();

                      final data = await Clipboard.getData('text/plain');

                      final b64Secret = getIt<SyncConfigService>()
                          .generateKeyFromPassphrase(passphrase);

                      final encryptedSyncCfg = data?.text;

                      if (encryptedSyncCfg != null) {
                        final decryptedConfig = await decryptString(
                          encrypted: encryptedSyncCfg,
                          b64Secret: b64Secret,
                        );

                        await syncConfigCubit.setSyncConfig(decryptedConfig);
                      }
                      navigator.pop('Import SyncConfig');
                    },
                    primaryColor: Colors.red,
                  ),
                ],
              ),
            );
          },
          primaryColor: Colors.red,
        ),
      ],
    );
  }
}

class DeleteSyncKeyButton extends StatelessWidget {
  const DeleteSyncKeyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    return Button(
      localizations.settingsSyncDeleteKeyButton,
      onPressed: () {
        context.read<SyncConfigCubit>().deleteSharedKey();
        persistNamedRoute('/settings/advanced');
        maybePop();
      },
      primaryColor: Colors.red,
    );
  }
}

class DeleteSyncConfigButton extends StatelessWidget {
  const DeleteSyncConfigButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Button(
      localizations.settingsSyncDeleteConfigButton,
      onPressed: () {
        context.read<SyncConfigCubit>().deleteImapConfig();
        context.read<SyncConfigCubit>().deleteSharedKey();
      },
      primaryColor: Colors.red,
    );
  }
}

class StatusTextWidget extends StatelessWidget {
  const StatusTextWidget(
    this.label, {
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        style: monospaceTextStyle(),
      ),
    );
  }
}
