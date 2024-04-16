import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/sync/state/matrix_config_provider.dart';
import 'package:lotti/sync/state/matrix_login_provider.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const matrixUserKey = 'user';
const matrixPasswordKey = 'password';
const matrixHomeServerKey = 'home_server';
const matrixRoomIdKey = 'room_id';

SliverWoltModalSheetPage homeServerConfigPage({
  required BuildContext context,
  required TextTheme textTheme,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  final localizations = AppLocalizations.of(context)!;

  return WoltModalSheetPage(
    stickyActionBar: HomeserverConfigPageStickyActionBar(
      pageIndexNotifier: pageIndexNotifier,
    ),
    topBarTitle: Text(
      localizations.settingsMatrixHomeserverConfigTitle,
      style: textTheme.titleMedium,
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: IconButton(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      child: HomeserverSettingsWidget(
        pageIndexNotifier: pageIndexNotifier,
      ),
    ),
  );
}

class HomeserverConfigPageStickyActionBar extends ConsumerWidget {
  const HomeserverConfigPageStickyActionBar({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Center(
              child: Text(localizations.settingsMatrixCancel),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('matrix_login'),
            onPressed: () async {
              await ref.read(matrixLoginControllerProvider.notifier).login();
              pageIndexNotifier.value = 1;
            },
            child: Text(
              localizations.settingsMatrixLoginButtonLabel,
              semanticsLabel: localizations.settingsMatrixLoginButtonLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeserverSettingsWidget extends ConsumerStatefulWidget {
  const HomeserverSettingsWidget({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<HomeserverSettingsWidget> createState() =>
      _HomeserverSettingsWidgetState();
}

class _HomeserverSettingsWidgetState
    extends ConsumerState<HomeserverSettingsWidget> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    final isLoggedIn = ref.read(isLoggedInProvider).valueOrNull ?? false;
    if (isLoggedIn) {
      widget.pageIndexNotifier.value = 1;
    }
  }

  void onFormChanged() {
    _formKey.currentState?.save();
    setState(() => _dirty = true);
  }

  Future<void> onSavePressed() async {
    final currentState = _formKey.currentState;

    if (currentState == null) {
      return;
    }

    final formData = currentState.value;
    currentState.save();

    if (currentState.validate()) {
      final previous = ref.read(matrixConfigControllerProvider).value;

      final config = MatrixConfig(
        homeServer: formData[matrixHomeServerKey] as String? ??
            previous?.homeServer ??
            '',
        user: formData[matrixUserKey] as String? ?? previous?.user ?? '',
        password:
            formData[matrixPasswordKey] as String? ?? previous?.password ?? '',
      );

      await ref.read(matrixConfigControllerProvider.notifier).setConfig(config);
      setState(() => _dirty = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    final config = ref.watch(matrixConfigControllerProvider);

    return config.map(
      data: (data) {
        final config = data.value;
        return FormBuilder(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          onChanged: onFormChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FormBuilderTextField(
                name: matrixHomeServerKey,
                validator: FormBuilderValidators.required(),
                initialValue: config?.homeServer,
                decoration: inputDecoration(
                  labelText: localizations.settingsMatrixHomeServerLabel,
                  themeData: Theme.of(context),
                ),
              ),
              const SizedBox(height: 20),
              FormBuilderTextField(
                name: matrixUserKey,
                validator: FormBuilderValidators.required(),
                initialValue: config?.user,
                decoration: inputDecoration(
                  labelText: localizations.settingsMatrixUserLabel,
                  themeData: Theme.of(context),
                ),
              ),
              const SizedBox(height: 20),
              FormBuilderTextField(
                name: matrixPasswordKey,
                initialValue: config?.password,
                obscureText: true,
                validator: FormBuilderValidators.required(),
                decoration: inputDecoration(
                  labelText: localizations.settingsMatrixPasswordLabel,
                  themeData: Theme.of(context),
                ),
              ),
              SizedBox(
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (config != null)
                      OutlinedButton(
                        key: const Key('matrix_config_delete'),
                        onPressed: () async {
                          await ref
                              .read(matrixConfigControllerProvider.notifier)
                              .deleteConfig();

                          setState(() {
                            _dirty = false;
                          });
                          maybePop();
                        },
                        child: Text(
                          localizations.settingsMatrixDeleteLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          semanticsLabel: 'Delete Matrix Config',
                        ),
                      ),
                    if (_dirty)
                      OutlinedButton(
                        key: const Key('matrix_config_save'),
                        onPressed: () {
                          onSavePressed();
                          maybePop();
                        },
                        child: Text(
                          localizations.settingsMatrixSaveLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          semanticsLabel: 'Save Matrix Config',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
      error: (_) => const CircularProgressIndicator(),
      loading: (_) => const CircularProgressIndicator(),
    );
  }
}
