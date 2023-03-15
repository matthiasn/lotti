import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('DeleteIconWidget', () {
    final entryCubit = MockEntryCubit();

    setUpAll(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
    });

    testWidgets('calls delete in cubit', (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
          isFocused: false,
        ),
      );

      when(entryCubit.delete).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const DeleteIconWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trashIconFinder = find.byIcon(Icons.delete);
      expect(trashIconFinder, findsOneWidget);

      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final warningIconFinder = find.byIcon(Icons.warning);
      expect(warningIconFinder, findsOneWidget);

      await tester.tap(warningIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.delete).called(1);
    });
  });
}
