import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../../widget_test_utils.dart';

class TestEntryController extends EntryController {
  TestEntryController({required this.showToolbar, this.onSave});

  final bool showToolbar;
  final VoidCallback? onSave;

  @override
  Future<EntryState?> build() async {
    controller = QuillController.basic();
    return EntryState.saved(
      entryId: id,
      entry: null,
      showMap: false,
      isFocused: showToolbar,
      shouldShowEditorToolBar: showToolbar,
      formKey: formKey,
    );
  }

  @override
  Future<void> save({
    Duration? estimate,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool stopRecording = false,
  }) async {
    onSave?.call();
  }
}

Widget buildEditorTestWidget({
  required String entryId,
  required bool showToolbar,
  SpeechDictionaryService? speechDictionaryServiceOverride,
  EdgeInsets? margin,
  VoidCallback? onSave,
  TargetPlatform platform = TargetPlatform.windows,
}) {
  return ProviderScope(
    overrides: [
      entryControllerProvider(entryId).overrideWith(
        () => TestEntryController(showToolbar: showToolbar, onSave: onSave),
      ),
      if (speechDictionaryServiceOverride != null)
        speechDictionaryServiceProvider.overrideWithValue(
          speechDictionaryServiceOverride,
        ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppCommandHost(
          handlers: const <AppCommandId, AppCommandHandler>{},
          platform: platform,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 800,
                  maxWidth: 800,
                ),
                child: EditorWidget(entryId: entryId, margin: margin),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
