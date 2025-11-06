import 'package:flutter/material.dart';

class DiagnosticsPanel extends StatefulWidget {
  const DiagnosticsPanel({
    required this.fetchDiagnostics,
    super.key,
  });

  final Future<String> Function() fetchDiagnostics;

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  bool _expanded = false;
  Future<String>? _future;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Diagnostics'),
      onExpansionChanged: (open) {
        setState(() {
          _expanded = open;
          if (_expanded) {
            _future ??= widget.fetchDiagnostics();
          }
        });
      },
      children: [
        if (_expanded)
          FutureBuilder<String>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }
              final txt = snap.data ?? '';
              final lines =
                  txt.split('\n').where((l) => l.contains('=')).toList();
              final diag = <String, String>{};
              for (final l in lines) {
                final i = l.indexOf('=');
                if (i > 0) {
                  diag[l.substring(0, i)] = l.substring(i + 1);
                }
              }
              final dbMissingBase = diag['dbMissingBase'] ?? '0';
              final stalePurges = diag['staleAttachmentPurges'] ?? '0';
              final ignoredCount =
                  int.tryParse(diag['lastIgnoredCount'] ?? '0') ?? 0;
              // Prefetch details removed.
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('dbMissingBase: $dbMissingBase'),
                              Text('staleAttachmentPurges: $stalePurges'),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh diagnostics',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => setState(() {
                            _future = widget.fetchDiagnostics();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (ignoredCount > 0) ...[
                      const Text('Last Ignored:'),
                      for (var i = 1; i <= ignoredCount; i++)
                        Text(diag['lastIgnored.$i'] ?? ''),
                      const SizedBox(height: 6),
                    ],
                    // Prefetch details removed.
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
