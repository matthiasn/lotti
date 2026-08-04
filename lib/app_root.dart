import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/get_it.dart';

/// Root widget above the ProviderScope. Deliberately Riverpod-free: on a
/// profile switch the entire scope below is discarded via a new generation
/// key, so every provider — including the getIt bridge overrides — rebinds
/// against the freshly registered service generation.
class LottiAppRoot extends StatefulWidget {
  const LottiAppRoot({super.key});

  @override
  State<LottiAppRoot> createState() => LottiAppRootState();
}

class LottiAppRootState extends State<LottiAppRoot> {
  int _generation = 0;

  /// Discards the current ProviderScope and rebuilds it against the current
  /// getIt registrations. Called by the profile switcher after it has torn
  /// down the old generation and bootstrapped the new one.
  void bumpGeneration() {
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('profile-gen-$_generation'),
      overrides: buildProviderOverrides(getIt<ProfileContext>()),
      child: const MyBeamerApp(),
    );
  }
}
