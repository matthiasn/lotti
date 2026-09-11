/// Standalone penguin-fixture client of the integrated plaza explorer.
/// Run with `fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart`.
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart' show SystemNavigator;

import 'package:lotti/features/demo/seed/demo_world.dart' show manualDemoNow;
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/project_world_generator.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_view.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const PlazaDevApp());

class PlazaDevApp extends StatelessWidget {
  const PlazaDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    final env = Platform.environment;
    return MaterialApp(
      builder: LegacyMaterialBridge.builder,
      debugShowCheckedModeBanner: false,
      theme: DesignSystemTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => PlazaView(
          world: PlazaWorld(
            tasks: plazaTasksFromDemoWorld(now: manualDemoNow),
            connections: plazaConnectionsFromDemoWorld(now: manualDemoNow),
            now: manualDemoNow,
            projectLabel: 'Project Waddle',
            categoryLabels: demoCategoryLabels(now: manualDemoNow),
            layout: const ProjectWorldConfig(seed: 1337).layoutFor('waddle'),
            copy: PlazaCopy(context.messages),
          ),
          mode: HarnessMode.fromEnvironment(env),
          hidden: {...?env['PLAZA_HIDE']?.split(',')},
          trace: env['PLAZA_TRACE'] == '1',
          tourOnly: env['PLAZA_TOUR_ONLY']?.split(',').toSet(),
          shotDir: env['PLAZA_SHOT_DIR'],
          initialFrameRate: PlazaFrameRate.fromEnvironment(env),
          initialSkyMode: PlazaSkyMode.fromEnvironment(env),
          initialToolbarOpen: env['PLAZA_TOOLBAR'] == '1',
          // The harness is a client of the same chrome the app gets, so it
          // renders the same Back button. There is no route under this one,
          // so leaving the world means leaving the harness: the channel's
          // contract is "close the application, or the closest equivalent"
          // (`SystemChannels.platform`), which the macOS embedder implements.
          // Preferred over `dart:io`'s `exit`, which the framework warns can
          // look to the platform as though the app had crashed.
          onExit: SystemNavigator.pop,
        ),
      ),
    );
  }
}
