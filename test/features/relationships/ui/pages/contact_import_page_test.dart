import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/ui/pages/contact_import_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _FakeContactsService implements ContactsService {
  bool supported = true;
  ContactsAccess access = ContactsAccess.granted;
  List<ImportedContact> contacts = const [];
  int settingsOpened = 0;
  int accessRequests = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<ContactsAccess> requestReadAccess() async {
    accessRequests++;
    return access;
  }

  @override
  Future<List<ImportedContact>> readAll() async => contacts;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async => settingsOpened++;
}

void main() {
  final testDate = DateTime(2026, 8, 17, 12);

  late _FakeContactsService service;
  late MockRelationshipRepository repository;

  setUpAll(registerAllFallbackValues);

  ImportedContact contact(
    String id,
    String name, {
    List<ContactChannel> channels = const [],
  }) => (id: id, displayName: name, channels: channels);

  setUp(() {
    service = _FakeContactsService();
    repository = MockRelationshipRepository();
    when(
      () => repository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => RelationshipEntry(
        meta: Metadata(
          id: 'rel-new',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'x',
          status: RelationshipStatus.active(
            id: 's',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ContactImportPage(),
        overrides: [
          contactsServiceProvider.overrideWithValue(service),
          relationshipRepositoryProvider.overrideWithValue(repository),
          // The import writes the OS id into this device's own ref slot, so
          // the key has to resolve without a live sync host id behind it.
          contactRefKeyProvider.overrideWith((ref) async => 'android:host-a'),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('permission states', () {
    testWidgets('explains what access is for and offers to ask again when '
        'refused', (tester) async {
      service.access = ContactsAccess.denied;

      await pump(tester);

      expect(find.text('Allow access'), findsOneWidget);
      expect(
        find.textContaining('only while this picker is open'),
        findsOneWidget,
      );
    });

    testWidgets('re-requests access when the user asks again', (tester) async {
      service.access = ContactsAccess.denied;
      await pump(tester);

      await tester.tap(find.text('Allow access'));
      await tester.pumpAndSettle();

      expect(service.accessRequests, 2);
    });

    testWidgets('sends the user to settings when the refusal is permanent', (
      tester,
    ) async {
      service.access = ContactsAccess.permanentlyDenied;

      await pump(tester);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(service.settingsOpened, 1);
    });

    testWidgets('offers a retry alongside settings, for the user who granted '
        'access and came back', (tester) async {
      service.access = ContactsAccess.permanentlyDenied;
      await pump(tester);

      service
        ..access = ContactsAccess.granted
        ..contacts = [contact('a', 'Anna')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets(
      'explains itself on desktop rather than showing an empty list',
      (tester) async {
        service.supported = false;

        await pump(tester);

        expect(
          find.textContaining('available on phones and tablets'),
          findsOneWidget,
        );
        expect(service.accessRequests, 0);
      },
    );

    testWidgets('distinguishes an empty address book from a refusal', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('No contacts on this device'), findsOneWidget);
    });
  });

  group('selecting', () {
    setUp(() {
      service.contacts = [
        contact(
          'a',
          'Anna Schmidt',
          channels: [
            const ContactChannel(
              type: ContactChannelType.mobile,
              value: '+15550109999',
            ),
          ],
        ),
        contact('b', 'Bo Larsen'),
      ];
    });

    testWidgets('lists the address book with channels as the subtitle', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Anna Schmidt'), findsOneWidget);
      expect(find.text('+15550109999'), findsOneWidget);
      expect(find.text('Bo Larsen'), findsOneWidget);
    });

    testWidgets('shows no action bar until somebody is chosen', (tester) async {
      await pump(tester);

      expect(find.textContaining('Review'), findsNothing);
    });

    testWidgets('counts the selection on the advance button', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Anna Schmidt'));
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);

      await tester.tap(find.text('Bo Larsen'));
      await tester.pumpAndSettle();

      expect(find.text('Review 2'), findsOneWidget);
    });

    testWidgets('filters the list as the user searches', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'bo');
      await tester.pumpAndSettle();

      expect(find.text('Bo Larsen'), findsOneWidget);
      expect(find.text('Anna Schmidt'), findsNothing);
    });

    testWidgets('says so when the search matches nobody', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('No contacts match your search'), findsOneWidget);
    });
  });

  group('reviewing', () {
    setUp(() {
      service.contacts = [contact('a', 'Anna Schmidt')];
    });

    Future<void> advanceToReview(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.text('Anna Schmidt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks who to nurture before creating anyone', (tester) async {
      await advanceToReview(tester);

      expect(find.text('Before you add them'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('hides the cadence until a person is marked important — a '
        'cadence on an unimportant person is never evaluated', (tester) async {
      await advanceToReview(tester);

      expect(find.byType(ChoiceChip), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('going back keeps the selection', (tester) async {
      await advanceToReview(tester);

      await tester.tap(find.byIcon(LottiIcons.back));
      await tester.pumpAndSettle();

      expect(
        find.text('Review 1'),
        findsOneWidget,
        reason: 'stepping back to change the picks must not discard them',
      );
    });

    testWidgets('creates one person per reviewed contact', (tester) async {
      await advanceToReview(tester);

      await tester.tap(find.text('Add 1 person'));
      await tester.pumpAndSettle();

      verify(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    testWidgets('returns to the caller with the count and confirms there', (
      tester,
    ) async {
      // Pushed from a host route, the way the People list opens it: the page
      // pops itself on success, so the confirmation has to land on the
      // screen underneath rather than on the one going away.
      int? popped;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<int>(
                      MaterialPageRoute(
                        builder: (_) => const ContactImportPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [
            contactsServiceProvider.overrideWithValue(service),
            relationshipRepositoryProvider.overrideWithValue(repository),
            contactRefKeyProvider.overrideWith(
              (ref) async => 'android:host-a',
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anna Schmidt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 person'));
      await tester.pumpAndSettle();

      expect(popped, 1, reason: 'the caller needs the count to react');
      expect(find.text('1 person added'), findsOneWidget);
      expect(
        find.text('Anna Schmidt'),
        findsNothing,
        reason: 'the import screen is done and should be gone',
      );
    });

    testWidgets('reports a failure instead of claiming success', (
      tester,
    ) async {
      when(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      await advanceToReview(tester);
      await tester.tap(find.text('Add 1 person'));
      await tester.pumpAndSettle();

      expect(find.text('Could not add anyone'), findsOneWidget);
    });

    testWidgets('shows the channels of each chosen contact while reviewing', (
      tester,
    ) async {
      service.contacts = [
        contact(
          'a',
          'Anna Schmidt',
          channels: [
            const ContactChannel(
              type: ContactChannelType.mobile,
              value: '+15550109999',
            ),
          ],
        ),
      ];

      await advanceToReview(tester);

      expect(
        find.text('+15550109999'),
        findsOneWidget,
        reason:
            'the review step is where the user confirms what will be '
            'copied, so it has to show it',
      );
    });

    testWidgets('records the cadence chosen for an important person', (
      tester,
    ) async {
      await advanceToReview(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every two weeks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 person'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => repository.createRelationship(
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: any(named: 'categoryId'),
                ),
              ).captured.single
              as RelationshipData;

      expect(data.checkInCadenceDays, 14);
    });

    testWidgets('carries the importance decision onto the created person', (
      tester,
    ) async {
      await advanceToReview(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 person'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => repository.createRelationship(
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: any(named: 'categoryId'),
                ),
              ).captured.single
              as RelationshipData;

      expect(data.important, isTrue);
    });
  });
}
