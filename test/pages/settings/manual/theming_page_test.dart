import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/theming/theming_cubit.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/theming_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../widget_test_utils.dart';

class MockThemingCubit extends Mock implements ThemingCubit {
  @override
  Stream<ThemingState> get stream => Stream.value(
        ThemingState(
          enableTooltips: true,
          themeMode: ThemeMode.system,
          lightThemeName: 'Light Theme',
          darkThemeName: 'Dark Theme',
          darkTheme: ThemeData.dark(),
          lightTheme: ThemeData.light(),
        ),
      );
}

class MockUserActivityService extends Mock implements UserActivityService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockThemingCubit mockThemingCubit;
  late MockUserActivityService mockUserActivityService;

  group('ThemingPage Widget Tests - ', () {
    setUp(() {
      mockThemingCubit = MockThemingCubit();
      mockUserActivityService = MockUserActivityService();

      when(() => mockThemingCubit.state).thenReturn(
        ThemingState(
          enableTooltips: true,
          themeMode: ThemeMode.system,
          lightThemeName: 'Light Theme',
          darkThemeName: 'Dark Theme',
          darkTheme: ThemeData.dark(),
          lightTheme: ThemeData.light(),
        ),
      );

      getIt.registerSingleton<UserActivityService>(mockUserActivityService);
    });

    tearDown(getIt.reset);

    testWidgets('showcase is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<ThemingCubit>.value(
            value: mockThemingCubit,
            child: ShowCaseWidget(
              builder: (context) => const ThemingPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the info icon in the app bar
      final iconFinder = find.byIcon(Icons.info_outline_rounded);
      expect(iconFinder, findsOneWidget);

      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      // Verify first showcase is visible
      expect(
        find.text(
          'Select your preferred theme mode: Light, Dark, or Automatic.',
        ),
        findsOneWidget,
      );
      expect(find.text('next'), findsOneWidget);
      expect(find.text('close'), findsOneWidget);
    });
  });
}
