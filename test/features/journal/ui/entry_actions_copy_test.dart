// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill_localizations;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';

// A lightweight test controller that returns a minimal entry state and
// exposes the base copy methods via super.* for coverage.
class TestEntryController extends EntryController {
  TestEntryController({this.initialText = ''});

  final String initialText;

  bool plainCalled = false;
  bool markdownCalled = false;

  @override
  Future<EntryState?> build({required String id}) async {
    // Initialize controller with initial text
    controller = QuillController.basic();
    if (initialText.isNotEmpty) {
      controller.document.insert(0, initialText);
    }

    final fixed = DateTime.utc(2023);
    final entry = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: fixed,
        updatedAt: fixed,
        dateFrom: fixed,
        dateTo: fixed,
      ),
    );

    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: true,
    );
  }

  @override
  Future<void> copyEntryTextPlain() async {
    plainCalled = true;
    await super.copyEntryTextPlain();
  }

  @override
  Future<void> copyEntryTextMarkdown() async {
    markdownCalled = true;
    await super.copyEntryTextMarkdown();
  }
}

// Clipboard is abstracted via provider; tests override with a closure-backed
// AppClipboard instance where needed.

Widget _wrapWithApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await getIt.reset(dispose: true);
    getIt
      ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
      ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
      ..registerSingleton<UpdateNotifications>(UpdateNotifications())
      ..registerSingleton<EditorStateService>(EditorStateService());
  });

  testWidgets('Copy as text triggers copy', (tester) async {
    final controller = TestEntryController(initialText: 'Hello');
    String? last;
    final fakeClipboard = AppClipboard(
      writePlainText: (t) async {
        last = t;
      },
    );

    await tester.pumpWidget(
      _wrapWithApp(
        Column(
          children: const [
            ModernCopyEntryTextItem(entryId: 'e1', markdown: false),
          ],
        ),
        overrides: [
          entryControllerProvider(id: 'e1').overrideWith(() => controller),
          appClipboardProvider.overrideWithValue(fakeClipboard),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy as text'), findsOneWidget);

    await tester.tap(find.text('Copy as text'));
    await tester.pump();

    expect(controller.plainCalled, isTrue);
    expect(last, 'Hello\n');
  });

  testWidgets('Copy as Markdown triggers copy', (tester) async {
    final controller = TestEntryController(initialText: 'Hello');
    String? last;
    final fakeClipboard = AppClipboard(
      writePlainText: (t) async {
        last = t;
      },
    );

    await tester.pumpWidget(
      _wrapWithApp(
        Column(
          children: const [
            ModernCopyEntryTextItem(entryId: 'e1', markdown: true),
          ],
        ),
        overrides: [
          entryControllerProvider(id: 'e1').overrideWith(() => controller),
          appClipboardProvider.overrideWithValue(fakeClipboard),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy as Markdown'), findsOneWidget);

    await tester.tap(find.text('Copy as Markdown'));
    await tester.pump();

    expect(controller.markdownCalled, isTrue);
    expect(last, 'Hello');
  });

  testWidgets('Copy actions hidden when no text', (tester) async {
    final controller = TestEntryController(initialText: '');

    await tester.pumpWidget(
      _wrapWithApp(
        Column(
          children: const [
            ModernCopyEntryTextItem(entryId: 'e2', markdown: false),
            ModernCopyEntryTextItem(entryId: 'e2', markdown: true),
          ],
        ),
        overrides: [
          entryControllerProvider(id: 'e2').overrideWith(() => controller),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy as text'), findsNothing);
    expect(find.text('Copy as Markdown'), findsNothing);
  });

  testWidgets('Editor toolbar builds (coverage)', (tester) async {
    final controller = TestEntryController(initialText: 'Toolbar');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        entryControllerProvider(id: 'e3').overrideWith(() => controller),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          quill_localizations.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: EditorWidget(entryId: 'e3'),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
  });

  testWidgets('InitialModalPageContent includes copy actions', (tester) async {
    final controller = TestEntryController(initialText: 'Hello');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        entryControllerProvider(id: 'e4').overrideWith(() => controller),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          quill_localizations.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InitialModalPageContent(
              entryId: 'e4',
              linkedFromId: null,
              inLinkedEntries: false,
              link: null,
              pageIndexNotifier: ValueNotifier(0),
            ),
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Copy as text'), findsOneWidget);
    expect(find.text('Copy as Markdown'), findsOneWidget);
  });
}
