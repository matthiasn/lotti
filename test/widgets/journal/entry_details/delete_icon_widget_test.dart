import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../journal_test_data/test_data.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockEntryCubit extends MockBloc<EntryCubit, EntryState>
    implements EntryCubit {}

void main() {
  group('DeleteIconWidget', () {
    final entryCubit = MockEntryCubit();
    final mockAppRouter = MockAppRouter();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<AppRouter>(mockAppRouter);
    });

    testWidgets('calls delete in cubit', (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
        ),
      );

      when(entryCubit.delete).thenAnswer((_) async {
        return true;
      });

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const DeleteIconWidget(
              popOnDelete: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final trashIconFinder = find.byIcon(MdiIcons.trashCanOutline);
      expect(trashIconFinder, findsOneWidget);

      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final warningIconFinder = find.byIcon(Icons.warning);
      expect(warningIconFinder, findsOneWidget);

      await tester.tap(warningIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.delete).called(1);
    });

    testWidgets('calls delete in cubit and pops navigation',
        (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
        ),
      );

      when(entryCubit.delete).thenAnswer((_) async {
        return true;
      });

      when(mockAppRouter.pop).thenAnswer((_) async {
        return true;
      });

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const DeleteIconWidget(
              popOnDelete: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final trashIconFinder = find.byIcon(MdiIcons.trashCanOutline);
      expect(trashIconFinder, findsOneWidget);

      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final warningIconFinder = find.byIcon(Icons.warning);
      expect(warningIconFinder, findsOneWidget);

      await tester.tap(warningIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.delete).called(1);
      verify(mockAppRouter.pop).called(1);
    });
  });
}
