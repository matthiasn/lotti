/// Standalone dev entrypoint to preview the knowledge-graph POC interactively
/// (pan / zoom / tap), without wiring it into the real app routes.
///
/// Run it directly, e.g.:
///   fvm flutter run -t lib/features/knowledge_graph_poc/dev_main.dart -d macos
///   fvm flutter run -t lib/features/knowledge_graph_poc/dev_main.dart -d linux
///   fvm flutter run -t lib/features/knowledge_graph_poc/dev_main.dart -d DEVICE
///
/// This is a developer harness only — it is not part of the shipping app.
library;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';

void main() => runApp(const KnowledgeGraphDevApp());

class KnowledgeGraphDevApp extends StatefulWidget {
  const KnowledgeGraphDevApp({super.key});

  @override
  State<KnowledgeGraphDevApp> createState() => _KnowledgeGraphDevAppState();
}

class _KnowledgeGraphDevAppState extends State<KnowledgeGraphDevApp> {
  final List<GraphScenario> _scenarios = allScenarios();
  int _index = 0;
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_index];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true).copyWith(
        extensions: const [dsTokensLight],
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        extensions: const [dsTokensDark],
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Stack(
          children: [
            // Keyed so switching scenarios rebuilds the layout from scratch.
            Positioned.fill(
              child: KnowledgeGraphView(
                key: ValueKey('${scenario.name}-$_dark'),
                scenario: scenario,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _scenarios.length; i++)
                        ChoiceChip(
                          label: Text(_scenarios[i].name),
                          selected: i == _index,
                          onSelected: (_) => setState(() => _index = i),
                        ),
                      IconButton(
                        tooltip: 'Toggle theme',
                        icon: Icon(_dark ? Icons.dark_mode : Icons.light_mode),
                        onPressed: () => setState(() => _dark = !_dark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
