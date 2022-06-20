import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';

Widget makeTestableWidget(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SingleChildScrollView(child: child),
    ),
  );
}

class ContainerByColorFinder extends MatchFinder {
  ContainerByColorFinder(this.color, {super.skipOffstage});

  final Color color;

  @override
  String get description => 'Container{color: "$color"}';

  @override
  bool matches(Element candidate) {
    if (candidate.widget is Container) {
      final containerWidget = candidate.widget as Container;
      if (containerWidget.decoration is BoxDecoration) {
        final decoration = containerWidget.decoration as BoxDecoration?;
        return decoration?.color?.value == color.value;
      }
    }
    return false;
  }
}

extension ContainerByColorFinderExtension on CommonFinders {
  Finder byContainerColor({required Color color, bool skipOffstage = true}) =>
      ContainerByColorFinder(color, skipOffstage: skipOffstage);
}
