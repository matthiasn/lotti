import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/labels/ui/widgets/category_selection_chip.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/features/speech_dictionary/state/speech_dictionary_controller.dart';
import 'package:lotti/features/speech_dictionary/ui/pages/speech_dictionary_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

Finder _pill(String label) => find.byWidgetPredicate(
  (widget) => widget is DsGlassPill && widget.label == label,
);

CategoryDefinition _category(String id, String name) => CategoryDefinition(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  vectorClock: null,
  private: false,
  active: true,
  color: '#336699',
);

void main() {
  late MockSpeechDictionaryRepository repository;
  late MockEntitiesCacheService cache;
  late StreamController<List<SpeechDictionaryEntry>> entries;
  late List<String> beamedTo;
  late AppLocalizations messages;

  final kubernetes = SpeechDictionaryEntry(
    id: speechDictionaryEntryId('Kubernetes'),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    term: 'Kubernetes',
    vectorClock: null,
    categoryIds: const ['work'],
    misheardAs: const ['Kuber Nets', 'Q Bernetes'],
  );

  setUp(() async {
    cache = MockEntitiesCacheService();
    // The category picker reads the cache through the locator itself.
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
    when(() => cache.getCategoryById('work')).thenReturn(
      _category('work', 'Work'),
    );
    when(() => cache.getCategoryById('home')).thenReturn(
      _category('home', 'Home'),
    );
    when(() => cache.sortedCategories).thenReturn([
      _category('home', 'Home'),
      _category('work', 'Work'),
    ]);
    repository = MockSpeechDictionaryRepository();
    entries = StreamController<List<SpeechDictionaryEntry>>.broadcast();
    when(
      () => repository.watchEntries(
        includePrivate: any(named: 'includePrivate'),
      ),
    ).thenAnswer((_) => entries.stream);
    when(() => repository.entryForTerm(any())).thenAnswer((_) async => null);
    when(() => repository.delete(any())).thenAnswer((_) async {});
    when(
      () => repository.save(
        term: any(named: 'term'),
        categoryIds: any(named: 'categoryIds'),
        misheardAs: any(named: 'misheardAs'),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => kubernetes);
    beamedTo = [];
    beamToNamedOverride = beamedTo.add;
    messages = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await entries.close();
    await tearDownTestGetIt();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    SpeechDictionaryDetailsPage page, {
    List<Override> overrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1024, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        speechDictionaryRepositoryProvider.overrideWithValue(repository),
        entitiesCacheServiceProvider.overrideWithValue(cache),
        ...overrides,
      ]),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidget2(
          AppCommandHost(
            handlers: const <AppCommandId, AppCommandHandler>{},
            platform: TargetPlatform.windows,
            child: page,
          ),
        ),
      ),
    );
    await tester.pump();
    // The header's back-affordance fade-in runs for a second.
    await tester.pump(const Duration(milliseconds: 1100));
  }

  /// The edit form for [kubernetes], once the entry has arrived.
  Future<void> pumpEditing(WidgetTester tester) async {
    await pumpPage(tester, SpeechDictionaryDetailsPage(entryId: kubernetes.id));
    entries.add([kubernetes]);
    await tester.pump();
    await tester.pump();
  }

  bool pillEnabled(WidgetTester tester, String label) =>
      tester.widget<DsGlassPill>(_pill(label)).enabled;

  testWidgets('waits for the entry before showing the form', (tester) async {
    await pumpPage(tester, SpeechDictionaryDetailsPage(entryId: kubernetes.id));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(messages.settingsSpeechDictionaryEditTitle), findsNothing);
  });

  testWidgets('shows the term, its categories and misheard spellings', (
    tester,
  ) async {
    await pumpEditing(tester);

    expect(find.text(messages.settingsSpeechDictionaryEditTitle), findsWidgets);
    // The first field is the term; its hint happens to be the same example.
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Kubernetes',
    );
    expect(find.widgetWithText(CategorySelectionChip, 'Work'), findsOneWidget);
    expect(find.text('Kuber Nets; Q Bernetes'), findsOneWidget);
    // Nothing edited yet, so nothing to save.
    expect(pillEnabled(tester, messages.saveButton), isFalse);
  });

  testWidgets('saving an edit sends the whole form and the old entry', (
    tester,
  ) async {
    await pumpEditing(tester);

    // Removing the only category makes the term apply everywhere.
    await tester.tap(
      find.descendant(
        of: find.byType(CategorySelectionChip),
        matching: find.byIcon(LottiIcons.close),
      ),
    );
    await tester.pump();
    expect(
      find.text(messages.settingsSpeechDictionaryAllCategories),
      findsOneWidget,
    );
    await tester.enterText(
      find.text('Kuber Nets; Q Bernetes'),
      'Cuban Eddies; Cube Nettis',
    );
    await tester.pump();

    await tester.tap(_pill(messages.saveButton));
    await tester.pump();
    await tester.pump();

    verify(
      () => repository.save(
        term: 'Kubernetes',
        categoryIds: const [],
        misheardAs: const ['Cuban Eddies', 'Cube Nettis'],
        previous: kubernetes,
      ),
    ).called(1);
    expect(beamedTo, ['/settings/speech-dictionary']);
  });

  testWidgets('adding a term creates it from what was typed', (tester) async {
    await pumpPage(
      tester,
      const SpeechDictionaryDetailsPage(initialTerm: 'Lotti'),
    );

    expect(find.text('Lotti'), findsOneWidget);
    expect(pillEnabled(tester, messages.createButton), isTrue);

    await tester.tap(_pill(messages.createButton));
    await tester.pump();
    await tester.pump();

    verify(
      () => repository.save(
        term: 'Lotti',
        categoryIds: const [],
        misheardAs: const [],
      ),
    ).called(1);
  });

  testWidgets('an empty term cannot be created', (tester) async {
    await pumpPage(tester, const SpeechDictionaryDetailsPage());

    expect(pillEnabled(tester, messages.createButton), isFalse);
  });

  testWidgets('a term already in the dictionary is refused with a reason', (
    tester,
  ) async {
    when(
      () => repository.entryForTerm('Kubernetes'),
    ).thenAnswer((_) async => kubernetes);
    await pumpPage(
      tester,
      const SpeechDictionaryDetailsPage(initialTerm: 'Kubernetes'),
    );

    await tester.tap(_pill(messages.createButton));
    await tester.pump();
    await tester.pump();

    expect(find.text(messages.addToDictionaryDuplicate), findsOneWidget);
    expect(beamedTo, isEmpty);
  });

  testWidgets('choosing categories opens the category picker', (tester) async {
    await pumpEditing(tester);

    await tester.tap(
      find.text(messages.settingsSpeechDictionaryCategoriesChoose),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CategoryPickerSheet), findsOneWidget);
  });

  testWidgets('deleting asks first, then deletes and returns', (tester) async {
    await pumpEditing(tester);

    await tester.scrollUntilVisible(
      find.widgetWithText(SettingsDeleteRow, messages.deleteButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(SettingsDeleteRow, messages.deleteButton),
    );
    await tester.pump();

    expect(
      find.text(
        messages.settingsSpeechDictionaryDeleteConfirmMessage('Kubernetes'),
      ),
      findsOneWidget,
    );
    verifyNever(() => repository.delete(any()));

    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(DesignSystemButton),
          )
          .last,
    );
    await tester.pump();
    await tester.pump();

    verify(() => repository.delete(kubernetes.id)).called(1);
    expect(beamedTo, ['/settings/speech-dictionary']);
  });

  testWidgets('Ctrl+S saves an edit', (tester) async {
    await pumpEditing(tester);
    await tester.enterText(find.text('Kuber Nets; Q Bernetes'), 'Kuber Nets');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await tester.pump();

    verify(
      () => repository.save(
        term: 'Kubernetes',
        categoryIds: const ['work'],
        misheardAs: const ['Kuber Nets'],
        previous: kubernetes,
      ),
    ).called(1);
    expect(beamedTo, ['/settings/speech-dictionary']);
  });

  testWidgets('Ctrl+S with nothing edited saves nothing', (tester) async {
    await pumpEditing(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    verifyNever(
      () => repository.save(
        term: any(named: 'term'),
        categoryIds: any(named: 'categoryIds'),
        misheardAs: any(named: 'misheardAs'),
        previous: any(named: 'previous'),
      ),
    );
  });

  testWidgets('the back chevron returns to the list', (tester) async {
    await pumpEditing(tester);

    await tester.tap(find.byIcon(LottiIcons.chevronLeft));
    await tester.pump();

    expect(beamedTo, ['/settings/speech-dictionary']);
  });

  testWidgets('Cancel returns to the list without saving', (tester) async {
    await pumpEditing(tester);
    await tester.enterText(find.text('Kuber Nets; Q Bernetes'), 'Kuber Nets');
    await tester.pump();

    await tester.tap(_pill(messages.cancelButton));
    await tester.pump();

    expect(beamedTo, ['/settings/speech-dictionary']);
    verifyNever(
      () => repository.save(
        term: any(named: 'term'),
        categoryIds: any(named: 'categoryIds'),
        misheardAs: any(named: 'misheardAs'),
        previous: any(named: 'previous'),
      ),
    );
  });

  testWidgets('a refused empty term says why', (tester) async {
    await pumpPage(
      tester,
      const SpeechDictionaryDetailsPage(),
      overrides: [
        speechDictionaryEditorControllerProvider.overrideWithBuild(
          (ref, args) => const SpeechDictionaryEditorState(
            term: '',
            categoryIds: {},
            misheardAs: [],
            error: SpeechDictionaryEditorError.emptyTerm,
          ),
        ),
      ],
    );

    expect(
      find.text(messages.settingsSpeechDictionaryErrorEmpty),
      findsOneWidget,
    );
  });

  testWidgets('categories picked in the picker are shown by name', (
    tester,
  ) async {
    await pumpEditing(tester);

    await tester.tap(
      find.text(messages.settingsSpeechDictionaryCategoriesChoose),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byType(CategoryPickerSheet),
        matching: find.text('Home'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(messages.tasksLabelsSheetApply));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Sorted by name, whatever order they were picked in.
    expect(
      tester
          .widgetList<CategorySelectionChip>(find.byType(CategorySelectionChip))
          .map((chip) => chip.name),
      ['Home', 'Work'],
    );
    expect(pillEnabled(tester, messages.saveButton), isTrue);
  });

  testWidgets('cancelling the delete question keeps the entry', (
    tester,
  ) async {
    await pumpEditing(tester);

    await tester.scrollUntilVisible(
      find.widgetWithText(SettingsDeleteRow, messages.deleteButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(SettingsDeleteRow, messages.deleteButton),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          DesignSystemButton,
          messages.cancelButton,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => repository.delete(any()));
    expect(beamedTo, isEmpty);
  });
}
