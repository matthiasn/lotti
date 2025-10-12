// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/l10n/app_localizations.dart';

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

    final entry = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
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

Widget _wrapWithApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
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

  testWidgets('Copy as text triggers copy and pops', (tester) async {
    final controller = TestEntryController(initialText: 'Hello');

    await tester.pumpWidget(
      _wrapWithApp(
        const Column(
          children: [
            ModernCopyEntryTextPlainItem(entryId: 'e1'),
          ],
        ),
        overrides: [
          entryControllerProvider(id: 'e1').overrideWith(() => controller),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy as text'), findsOneWidget);

    await tester.tap(find.text('Copy as text'));
    await tester.pumpAndSettle();

    expect(controller.plainCalled, isTrue);

    final data = await Clipboard.getData('text/plain');
    // Quill adds a trailing newline for plain text
    expect(data?.text?.trim(), 'Hello');
  });

  testWidgets('Copy as Markdown triggers copy and pops', (tester) async {
    final controller = TestEntryController(initialText: 'Hello');

    await tester.pumpWidget(
      _wrapWithApp(
        const Column(
          children: [
            ModernCopyEntryTextMarkdownItem(entryId: 'e1'),
          ],
        ),
        overrides: [
          entryControllerProvider(id: 'e1').overrideWith(() => controller),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy as Markdown'), findsOneWidget);

    await tester.tap(find.text('Copy as Markdown'));
    await tester.pumpAndSettle();

    expect(controller.markdownCalled, isTrue);

    final data = await Clipboard.getData('text/plain');
    expect(data?.text, 'Hello');
  });

  testWidgets('Copy actions hidden when no text', (tester) async {
    final controller = TestEntryController(initialText: '');

    await tester.pumpWidget(
      _wrapWithApp(
        const Column(
          children: [
            ModernCopyEntryTextPlainItem(entryId: 'e2'),
            ModernCopyEntryTextMarkdownItem(entryId: 'e2'),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: EditorWidget(entryId: 'e3'),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
  });
}
