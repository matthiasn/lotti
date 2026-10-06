import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/state/speech_dictionary_controller.dart';
import 'package:lotti/features/speech_dictionary/ui/pages/speech_dictionary_list_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

SpeechDictionaryEntry _entry(
  String term, {
  List<String>? categoryIds,
  List<String>? misheardAs,
}) => SpeechDictionaryEntry(
  id: speechDictionaryEntryId(term),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  term: term,
  vectorClock: null,
  categoryIds: categoryIds,
  misheardAs: misheardAs,
);

CategoryDefinition _category(String id, String name) => CategoryDefinition(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  vectorClock: null,
  private: false,
  active: true,
);

void main() {
  late MockEntitiesCacheService cache;
  late List<String> beamedTo;
  late AppLocalizations messages;

  setUp(() async {
    await setUpTestGetIt();
    cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(
      () => cache.getCategoryById('work'),
    ).thenReturn(_category('work', 'Work'));
    when(
      () => cache.getCategoryById('home'),
    ).thenReturn(_category('home', 'home office'));
    beamedTo = [];
    beamToNamedOverride = beamedTo.add;
    messages = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpList(
    WidgetTester tester,
    List<SpeechDictionaryEntry> entries,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: withServiceOverrides([
          speechDictionaryEntriesProvider.overrideWith(
            (ref) => Stream.value(entries),
          ),
          entitiesCacheServiceProvider.overrideWithValue(cache),
        ]),
        child: makeTestableWidgetWithScaffold(const SpeechDictionaryListPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String subtitleOf(WidgetTester tester, String term) => tester
      .widget<DesignSystemListItem>(
        find.widgetWithText(DesignSystemListItem, term),
      )
      .subtitle!;

  testWidgets('each row says where its term applies', (tester) async {
    await pumpList(tester, [
      _entry('Lotti'),
      _entry('Kubernetes', categoryIds: ['work', 'home']),
      // A category this device does not know is left out.
      _entry('Kirkjubæjarklaustur', categoryIds: ['unknown']),
    ]);

    expect(
      subtitleOf(tester, 'Lotti'),
      messages.settingsSpeechDictionaryAllCategories,
    );
    expect(subtitleOf(tester, 'Kubernetes'), 'home office, Work');
    expect(
      subtitleOf(tester, 'Kirkjubæjarklaustur'),
      messages.settingsSpeechDictionaryAllCategories,
    );
  });

  testWidgets('tapping a row opens its entry', (tester) async {
    await pumpList(tester, [_entry('Lotti')]);

    await tester.tap(find.widgetWithText(DesignSystemListItem, 'Lotti'));

    expect(beamedTo, [
      '/settings/speech-dictionary/${speechDictionaryEntryId('Lotti')}',
    ]);
  });

  testWidgets('search also finds a term by a misheard spelling', (
    tester,
  ) async {
    await pumpList(tester, [
      _entry('Kubernetes', misheardAs: ['Cuban Eddies']),
      _entry('Lotti'),
    ]);

    await tester.enterText(find.byType(TextField).first, 'cuban eddies');
    await tester.pump();

    expect(find.widgetWithText(DesignSystemListItem, 'Kubernetes'), findsOne);
    expect(find.widgetWithText(DesignSystemListItem, 'Lotti'), findsNothing);
  });

  testWidgets('a search with no match offers adding it as a term', (
    tester,
  ) async {
    await pumpList(tester, [_entry('Lotti')]);

    await tester.enterText(find.byType(TextField).first, 'Kubernetes');
    await tester.pump();
    await tester.tap(
      find.text(messages.settingsSpeechDictionaryNoMatchCreate('Kubernetes')),
    );

    expect(beamedTo, ['/settings/speech-dictionary/create?term=Kubernetes']);
  });

  testWidgets('the create button opens an empty entry', (tester) async {
    await pumpList(tester, [_entry('Lotti')]);

    await tester.tap(
      find.bySemanticsLabel(messages.settingsSpeechDictionaryCreateTitle),
    );

    expect(beamedTo, ['/settings/speech-dictionary/create']);
  });

  testWidgets('an empty dictionary explains what it is for', (tester) async {
    await pumpList(tester, []);

    expect(
      find.text(messages.settingsSpeechDictionaryEmptyState),
      findsOneWidget,
    );
    expect(
      find.text(messages.settingsSpeechDictionaryEmptyStateHint),
      findsOneWidget,
    );
  });

  testWidgets('the panel body has no header of its own', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: withServiceOverrides([
          speechDictionaryEntriesProvider.overrideWith(
            (ref) => Stream.value([_entry('Lotti')]),
          ),
          entitiesCacheServiceProvider.overrideWithValue(cache),
        ]),
        child: makeTestableWidgetWithScaffold(const SpeechDictionaryListBody()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(messages.settingsSpeechDictionaryTitle), findsNothing);
    expect(find.widgetWithText(DesignSystemListItem, 'Lotti'), findsOneWidget);
  });
}
