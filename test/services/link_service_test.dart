import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/link_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkService Tests', () {
    late MockPersistenceLogic mockPersistenceLogic;
    late LinkService linkService;

    setUp(() {
      if (getIt.isRegistered<PersistenceLogic>()) {
        getIt.unregister<PersistenceLogic>();
      }

      mockPersistenceLogic = MockPersistenceLogic();

      getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      linkService = LinkService();

      // Stub HapticFeedback to avoid platform channel dependency under fake time
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        methodCall,
      ) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          return null;
        }
        return null;
      });
    });

    test('createLink does nothing when both IDs are null', () async {
      await linkService.createLink();

      verifyNever(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      );
    });

    test('createLink does nothing when only linkFromId is set', () {
      fakeAsync((async) {
        linkService.linkFrom('from-id');

        async.flushMicrotasks();

        verifyNever(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        );
      });
    });

    test('createLink creates link when both IDs are set via linkTo', () {
      fakeAsync((async) {
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });

    test('createLink creates link when both IDs are set via linkFrom', () {
      fakeAsync((async) {
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });
  });
}
