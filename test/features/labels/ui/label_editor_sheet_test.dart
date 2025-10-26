import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/l10n/app_localizations.dart';

class _FakeLabelEditorController extends LabelEditorController {
  _FakeLabelEditorController(this._state, {this.onPrivateChanged});

  LabelEditorState _state;
  final void Function({required bool isPrivate})? onPrivateChanged;

  @override
  LabelEditorState build(LabelEditorArgs args) => _state;

  @override
  void setPrivate({required bool isPrivateValue}) {
    onPrivateChanged?.call(isPrivate: isPrivateValue);
    _state = _state.copyWith(isPrivate: isPrivateValue);
    state = _state;
  }
}

Widget _sheetHost({LabelDefinition? label, String? initialName}) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(800, 1200),
    ),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LabelEditorSheet(
              label: label,
              initialName: initialName,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('save button disabled when name empty', (tester) async {
    const state = LabelEditorState(
      name: '',
      colorHex: '#FF0000',
      isPrivate: false,
    );

    final container = ProviderContainer(
      overrides: [
        labelEditorControllerProvider.overrideWith(
          () => _FakeLabelEditorController(state),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _sheetHost(),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Create');
    expect(createButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(createButton).onPressed,
      isNull,
    );
  });

  testWidgets('save button enabled when name provided', (tester) async {
    const state = LabelEditorState(
      name: 'Release blocker',
      colorHex: '#FF0000',
      isPrivate: false,
    );

    final container = ProviderContainer(
      overrides: [
        labelEditorControllerProvider.overrideWith(
          () => _FakeLabelEditorController(state),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _sheetHost(),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Create');
    expect(createButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(createButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('renders duplicate error message when provided', (tester) async {
    const state = LabelEditorState(
      name: 'Release blocker',
      colorHex: '#FF0000',
      isPrivate: false,
      errorMessage: 'A label with this name already exists.',
    );

    final container = ProviderContainer(
      overrides: [
        labelEditorControllerProvider.overrideWith(
          () => _FakeLabelEditorController(state),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _sheetHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A label with this name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping private toggle notifies controller', (tester) async {
    var toggledValue = false;
    const state = LabelEditorState(
      name: 'Urgent',
      colorHex: '#FF0000',
      isPrivate: false,
    );

    final container = ProviderContainer(
      overrides: [
        labelEditorControllerProvider.overrideWith(
          () => _FakeLabelEditorController(
            state,
            onPrivateChanged: ({required bool isPrivate}) =>
                toggledValue = isPrivate,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _sheetHost(initialName: 'Urgent'),
      ),
    );
    await tester.pumpAndSettle();

    final toggleFinder = find.byType(SwitchListTile);
    expect(toggleFinder, findsOneWidget);

    await tester.ensureVisible(toggleFinder);
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(toggledValue, isTrue);
  });
}
